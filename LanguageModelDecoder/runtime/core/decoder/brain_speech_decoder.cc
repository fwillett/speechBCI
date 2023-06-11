#include "decoder/brain_speech_decoder.h"

#include <ctype.h>

#include <algorithm>
#include <limits>
#include <utility>

#include "utils/string.h"
#include "utils/timer.h"

namespace wenet {

BrainSpeechDecoder::BrainSpeechDecoder(
    std::shared_ptr<DecodeResource> resource,
    std::shared_ptr<DecodeOptions> opts)
    : symbol_table_(resource->symbol_table),
      fst_(resource->fst),
      original_lm_fst_(resource->original_lm_fst),
      rescore_lm_fst_(resource->rescore_lm_fst),
      unit_table_(resource->unit_table),
      opts_(opts) {
  if (nullptr == fst_) {
    searcher_.reset(new CtcPrefixBeamSearch(opts_->ctc_prefix_search_opts));
  } else {
    searcher_.reset(new CtcWfstBeamSearch(*fst_, opts->ctc_wfst_search_opts));
    acoustic_scale_ = opts->ctc_wfst_search_opts.acoustic_scale;
  }
}

void BrainSpeechDecoder::SetOpt(const std::shared_ptr<DecodeOptions> opts) {
  opts_ = opts;
  acoustic_scale_ = opts->ctc_wfst_search_opts.acoustic_scale;
  (static_cast<CtcWfstBeamSearch*>(searcher_.get()))->SetOpt(opts->ctc_wfst_search_opts);
}

void BrainSpeechDecoder::Reset() {
  result_.clear();
  searcher_->Reset();
}

void BrainSpeechDecoder::FinishDecoding() {
  searcher_->FinalizeSearch();
  UpdateResult();
}

void BrainSpeechDecoder::LatticeRescore(kaldi::Lattice& lat_in,
                                        kaldi::CompactLattice* lat_out,
                                        std::shared_ptr<LMFst> lm_fst,
                                        float lm_scale) {
  // https://github.com/kaldi-asr/kaldi/blob/master/src/latbin/lattice-lmrescore.cc
  fst::ScaleLattice(fst::GraphLatticeScale(lm_scale), &lat_in);
  fst::ArcSort(&lat_in, fst::OLabelCompare<kaldi::LatticeArc>());
  kaldi::Lattice composed_lat;
  fst::Compose(lat_in, *(lm_fst.get()), &composed_lat);
  fst::Invert(&composed_lat);
  fst::DeterminizeLattice(composed_lat, lat_out);
  fst::ScaleLattice(fst::GraphLatticeScale(lm_scale), lat_out);
}

void BrainSpeechDecoder::Rescore() {
  Timer timer;
  timer.Reset();

  // Rescore by subtracting the original LM score and adding the new LM score.
  kaldi::Lattice decoded_lat = searcher_->Lattice();
  kaldi::CompactLattice clat_without_lm;
  kaldi::Lattice lat_without_lm;
  LatticeRescore(decoded_lat, &clat_without_lm, original_lm_fst_, -1.0);
  fst::ConvertLattice(clat_without_lm, &lat_without_lm);
  kaldi::CompactLattice lat_with_new_lm;
  LatticeRescore(lat_without_lm, &lat_with_new_lm, rescore_lm_fst_, 1.0);

  // Convert to nbest results.
  std::vector<kaldi::Lattice> nbest_lats;
  kaldi::Lattice lat, nbest_lat;
  fst::ConvertLattice(lat_with_new_lm, &lat);
  fst::ShortestPath(lat, &nbest_lat, result_.size());
  fst::ConvertNbestToVector(nbest_lat, &nbest_lats);

  std::vector<std::vector<int>> outputs;
  outputs.resize(result_.size());
  result_.clear();
  for (size_t i = 0; i < outputs.size(); ++i) {
    kaldi::LatticeWeight weight;
    std::vector<int> alignment;
    fst::GetLinearSymbolSequence(nbest_lats[i], &alignment, &outputs[i], &weight);

    DecodeResult path;
    path.lm_score = -weight.Value1();
    path.ac_score = -weight.Value2() / acoustic_scale_;
    for (size_t j = 0; j < outputs[i].size(); j++) {
      std::string word = symbol_table_->Find(outputs[i][j]);
      path.sentence += (' ' + word);
    }

    path.sentence = ProcessBlank(path.sentence);
    result_.emplace_back(path);
  }
  VLOG(1) << "Total rescore time: " << timer.Elapsed() << "ms";
}

void BrainSpeechDecoder::Decode(const torch::Tensor& logp) {
  Timer timer;

  timer.Reset();
  searcher_->Search(logp);
  int search_time = timer.Elapsed();
  VLOG(3) << "Search takes " << search_time << " ms";
  UpdateResult();
}

void BrainSpeechDecoder::UpdateResult() {
  const auto& hypotheses = searcher_->Outputs();
  const auto& likelihood = searcher_->Likelihood();
  result_.clear();

  CHECK_EQ(hypotheses.size(), likelihood.size());
  for (size_t i = 0; i < hypotheses.size(); i++) {
    const std::vector<int>& hypothesis = hypotheses[i];

    DecodeResult path;
    path.lm_score = likelihood[i].first;
    path.ac_score = likelihood[i].second / acoustic_scale_;
    for (size_t j = 0; j < hypothesis.size(); j++) {
      std::string word = symbol_table_->Find(hypothesis[j]);
      path.sentence += (' ' + word);
    }

    path.sentence = ProcessBlank(path.sentence);
    result_.emplace_back(path);
  }

  if (DecodedSomething()) {
    VLOG(1) << "Partial CTC result " << result_[0].sentence;
  }
}

}  // namespace wenet
#ifndef DECODER_BRAIN_SPEECH_DECODER_H_
#define DECODER_BRAIN_SPEECH_DECODER_H_

#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "fst/fstlib.h"
#include "fst/symbol-table.h"

#include "decoder/ctc_prefix_beam_search.h"
#include "decoder/ctc_wfst_beam_search.h"
#include "decoder/torch_asr_model.h"
#include "frontend/feature_pipeline.h"
#include "utils/utils.h"

namespace wenet {

using LMFst = fst::MapFst<fst::StdArc, kaldi::LatticeArc, fst::StdToLatticeMapper<kaldi::BaseFloat> >;

struct DecodeOptions {
  DecodeOptions(int max_active,
                int min_active,
                float beam,
                float lattice_beam,
                float acoustic_scale,
                float blank_skip_threshold,
                float length_penalty,
                int nbest) {
    ctc_wfst_search_opts.max_active = max_active;
    ctc_wfst_search_opts.min_active = min_active;
    ctc_wfst_search_opts.beam = beam;
    ctc_wfst_search_opts.lattice_beam = lattice_beam;
    ctc_wfst_search_opts.acoustic_scale = acoustic_scale;
    ctc_wfst_search_opts.blank_skip_thresh = blank_skip_threshold;
    ctc_wfst_search_opts.length_penalty = length_penalty;
    ctc_wfst_search_opts.nbest = nbest;
  }

  CtcPrefixBeamSearchOptions ctc_prefix_search_opts;
  CtcWfstBeamSearchOptions ctc_wfst_search_opts;
};

struct DecodeResource {
  DecodeResource(const string &fst_path,
                 const string &lm_fst_path,
                 const string &rescore_lm_fst_path,
                 const string &dict_path,
                 const string &unit_path) {
    if (!fst_path.empty()) {
      LOG(INFO) << "Reading fst " << fst_path;
      fst.reset(fst::Fst<fst::StdArc>::Read(fst_path));
      CHECK(fst != nullptr);
    }

    if (!lm_fst_path.empty()) {
      LOG(INFO) << "Reading lm fst " << lm_fst_path;
      auto std_lm_fst = fst::ReadAndPrepareLmFst(lm_fst_path);

      int32 num_states_cache = 50000;
      fst::CacheOptions cache_opts(true, num_states_cache);
      fst::MapFstOptions mapfst_opts(cache_opts);
      fst::StdToLatticeMapper<kaldi::BaseFloat> mapper;
      original_lm_fst.reset(new LMFst(*std_lm_fst, mapper, mapfst_opts));
      delete std_lm_fst;
    }

    if (!rescore_lm_fst_path.empty()) {
      LOG(INFO) << "Reading rescore fst " << rescore_lm_fst_path;
      auto std_lm_fst = fst::ReadAndPrepareLmFst(rescore_lm_fst_path);

      int32 num_states_cache = 50000;
      fst::CacheOptions cache_opts(true, num_states_cache);
      fst::MapFstOptions mapfst_opts(cache_opts);
      fst::StdToLatticeMapper<kaldi::BaseFloat> mapper;
      rescore_lm_fst.reset(new LMFst(*std_lm_fst, mapper, mapfst_opts));
      delete std_lm_fst;
    }

    LOG(INFO) << "Reading symbol table " << dict_path;
    symbol_table.reset(fst::SymbolTable::ReadText(dict_path));

    if (!unit_path.empty()) {
      unit_table.reset(fst::SymbolTable::ReadText(unit_path));
      CHECK(unit_table != nullptr);
    } else if (fst == nullptr) {
      LOG(INFO) << "Use symbol table as unit table";
      unit_table = symbol_table;
    }
  }

  std::shared_ptr<fst::SymbolTable> symbol_table = nullptr;
  std::shared_ptr<fst::Fst<fst::StdArc>> fst = nullptr;
  std::shared_ptr<fst::SymbolTable> unit_table = nullptr;
  std::shared_ptr<LMFst> rescore_lm_fst = nullptr;
  std::shared_ptr<LMFst> original_lm_fst = nullptr;
};

struct DecodeResult {
  float ac_score = -kFloatMax;
  float lm_score = -kFloatMax;
  std::string sentence;

  static bool CompareFunc(const DecodeResult& a, const DecodeResult& b) {
    return a.lm_score > b.lm_score;
  }
};

class BrainSpeechDecoder {
 public:
  BrainSpeechDecoder(std::shared_ptr<DecodeResource> resource,
                     std::shared_ptr<DecodeOptions> opts);

  void SetOpt(const std::shared_ptr<DecodeOptions> opts);
  void Decode(const torch::Tensor& logp);
  void Rescore();
  void Reset();
  void FinishDecoding();
  bool DecodedSomething() const {
    return !result_.empty() && !result_[0].sentence.empty();
  }

  const std::vector<DecodeResult>& result() const { return result_; }

 private:
  void UpdateResult();
  void LatticeRescore(kaldi::Lattice& lat_in, kaldi::CompactLattice* lat_out,
                      std::shared_ptr<LMFst> lm, float lm_scale);

  std::shared_ptr<fst::Fst<fst::StdArc>> fst_ = nullptr;
  std::shared_ptr<LMFst> original_lm_fst_ = nullptr;
  std::shared_ptr<LMFst> rescore_lm_fst_ = nullptr;
  // output symbol table
  std::shared_ptr<fst::SymbolTable> symbol_table_;
  // e2e unit symbol table
  std::shared_ptr<fst::SymbolTable> unit_table_ = nullptr;
  std::shared_ptr<DecodeOptions> opts_ = nullptr;

  std::unique_ptr<SearchInterface> searcher_;

  std::vector<DecodeResult> result_;

  float acoustic_scale_ = 1.0f;

 public:
  WENET_DISALLOW_COPY_AND_ASSIGN(BrainSpeechDecoder);
};

}  // namespace wenet

#endif  // DECODER_BRAIN_SPEECH_DECODER_H_
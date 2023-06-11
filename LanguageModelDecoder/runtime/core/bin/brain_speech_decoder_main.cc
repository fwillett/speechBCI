#include <iomanip>
#include <utility>

#include "torch/script.h"
#include"cnpy.h"

#include "decoder/brain_speech_decoder.h"
#include "utils/flags.h"
#include "utils/log.h"
#include "utils/string.h"
#include "utils/timer.h"
#include "utils/utils.h"

// Binary flags
DEFINE_bool(simulate_streaming, false, "simulate streaming input");
DEFINE_string(data_path, "", "numpy array contains ctc outputs");
DEFINE_string(result, "", "result output file");
DEFINE_bool(output_nbest, false, "write nbest results to output");

// DecodeOptions flags
DEFINE_int32(max_active, 7000, "max active states in ctc wfst search");
DEFINE_int32(min_active, 200, "min active states in ctc wfst search");
DEFINE_double(beam, 16.0, "beam in ctc wfst search");
DEFINE_double(lattice_beam, 10.0, "lattice beam in ctc wfst search");
DEFINE_double(acoustic_scale, 1.0, "acoustic scale for ctc wfst search");
DEFINE_double(blank_skip_thresh, 1.0,
              "blank skip thresh for ctc wfst search, 1.0 means no skip");
DEFINE_int32(nbest, 10, "nbest for ctc wfst search");

// TLG fst
DEFINE_string(fst_path, "", "TLG fst path");
DEFINE_string(lm_fst_path, "", "LM fst path");
DEFINE_string(rescore_lm_fst_path, "", "Rescore lm fst path");

// SymbolTable flags
DEFINE_string(dict_path, "",
              "dict symbol table path, it's same as unit_path when we don't "
              "use LM in decoding");
DEFINE_string(
    unit_path, "",
    "e2e model unit symbol table, used for get timestamp of the result");



int main(int argc, char *argv[]) {
  gflags::ParseCommandLineFlags(&argc, &argv, false);
  google::InitGoogleLogging(argv[0]);

  auto decode_config = std::make_shared<wenet::DecodeOptions>(FLAGS_max_active,
                                                              FLAGS_min_active,
                                                              FLAGS_beam,
                                                              FLAGS_lattice_beam,
                                                              FLAGS_acoustic_scale,
                                                              FLAGS_blank_skip_thresh,
                                                              0,  // Length penalty
                                                              FLAGS_nbest);
  auto decode_resource = std::make_shared<wenet::DecodeResource>(FLAGS_fst_path,
                                                                 FLAGS_lm_fst_path,
                                                                 FLAGS_rescore_lm_fst_path,
                                                                 FLAGS_dict_path,
                                                                 FLAGS_unit_path);

  if (FLAGS_data_path.empty()) {
    LOG(FATAL) << "data path is empty";
  }

  std::ofstream result;
  if (!FLAGS_result.empty()) {
    result.open(FLAGS_result, std::ios::out);
  }
  std::ostream &buffer = FLAGS_result.empty() ? std::cout : result;

  // Load np data
  LOG(INFO) << "Reading data from " << FLAGS_data_path;
  cnpy::NpyArray np_data = cnpy::npy_load(FLAGS_data_path);
  float* raw_data = np_data.data<float>();
  LOG(INFO) << "Data shape " << np_data.shape;
  torch::Tensor logits = torch::from_blob(raw_data,
    {static_cast<long>(np_data.shape[0]), static_cast<long>(np_data.shape[1]), static_cast<long>(np_data.shape[2])},
    torch::kFloat);//.permute({2, 1, 0});
  LOG(INFO) << logits.sizes();
  auto log_probs = torch::log_softmax(logits, -1);

  wenet::BrainSpeechDecoder decoder(decode_resource, decode_config);

  for (int i = 0; i < np_data.shape[0]; ++i) {
    for (int j = 0; j < np_data.shape[1]; ++j) {
      decoder.Decode(log_probs.index({i, torch::indexing::Slice(j, j + 1)}));
    }

    decoder.FinishDecoding();
    if (!FLAGS_rescore_lm_fst_path.empty()) {
      decoder.Rescore();
    }

    int num_to_write = 1;
    if (FLAGS_output_nbest) {
      num_to_write = decoder.result().size();
    }
    for (int k = 0; k < num_to_write; ++k) {
      auto &result = decoder.result()[k];
      LOG(INFO) << "Input " << i << ": " << result.sentence;
      buffer << i << " " << result.sentence;
      if (FLAGS_output_nbest) {
        buffer << " " << result.ac_score << " " << result.lm_score;
      }
      buffer << std::endl;
    }

    decoder.Reset();
  }

  return 0;
}
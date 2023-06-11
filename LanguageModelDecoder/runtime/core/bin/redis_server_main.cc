#include <iomanip>
#include <utility>
#include <memory>

#include "torch/script.h"

#include "decoder/brain_speech_decoder.h"
#include "third_party/redis-plus-plus/src/sw/redis++/redis++.h"
#include "utils/flags.h"
#include "utils/log.h"
#include "utils/string.h"
#include "utils/timer.h"
#include "utils/utils.h"

// Redis flags
DEFINE_string(redis_host, "localhost", "Redis host");
DEFINE_string(redis_port, "6379", "Redis port");

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

using Attrs = std::vector<std::pair<std::string, std::string>>;
using Item = std::pair<std::string, Attrs>;
using ItemStream = std::vector<Item>;


int main(int argc, char *argv[]) {
  gflags::ParseCommandLineFlags(&argc, &argv, false);
  google::InitGoogleLogging(argv[0]);

  auto decode_config = std::make_shared<wenet::DecodeOptions>(FLAGS_max_active,
                                                              FLAGS_min_active,
                                                              FLAGS_beam,
                                                              FLAGS_lattice_beam,
                                                              FLAGS_acoustic_scale,
                                                              FLAGS_blank_skip_thresh,
                                                              FLAGS_nbest);
  auto decode_resource = std::make_shared<wenet::DecodeResource>(FLAGS_fst_path,
                                                                 FLAGS_lm_fst_path,
                                                                 FLAGS_rescore_lm_fst_path,
                                                                 FLAGS_dict_path,
                                                                 FLAGS_unit_path);
  // Connect to Redis
  auto redis_url = "tcp://" + FLAGS_redis_host + ":" + FLAGS_redis_port;
  LOG(INFO) << "Connecting to Redis " << redis_url;
  auto redis = sw::redis::Redis(redis_url);

  // Init decoder
  std::unique_ptr<wenet::BrainSpeechDecoder> decoder;

  while (true) {
    std::unordered_map<std::string, ItemStream> result;
    redis.xread("binned:decoderOutput:stream", "$", std::chrono::seconds(1), 1,
                std::inserter(result, result.end()));
    LOG(INFO) << "Received " << result.size() << " messages";

    if (result.find("binned:decoderOutput:stream") == result.end()) {
      continue;
    }

    bool finished = false;
    auto& stream = result["binned:decoderOutput:stream"];
    for (const auto& s : stream) {
      for (const auto& attr : s.second) {
        if (attr.first == "start") {
          LOG(INFO) << "Start decoding ";;
          decoder.reset(new wenet::BrainSpeechDecoder(decode_resource, decode_config));
        } else if (attr.first == "data") {
          const float *buffer = reinterpret_cast<const float*>(attr.second.data());
          torch::Tensor logits =
              torch::from_blob(const_cast<float*>(buffer), {1, 40}, torch::kFloat);
          auto log_probs = torch::log_softmax(logits, 1);
          decoder->Decode(log_probs);
	  redis.set("decoded_sentence", "partial: " + decoder->result()[0].sentence);
        } else if (attr.first == "end") {
          finished = true;
          break;
        } else {
          LOG(WARNING) << "Unknown attribute " << attr.first;
        }
     }
    }
    if (finished) {
      decoder->FinishDecoding();
      LOG(INFO) << "Finish decoding";
      for (int i = 0; i < decoder->result().size(); ++i) {
        LOG(INFO) << "Top " << i << ": " << decoder->result()[i].sentence;
      }
      redis.set("decoded_sentence", "final: " + decoder->result()[0].sentence);
    }
  }

  return 0;
}

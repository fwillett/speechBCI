#include "pybind11/pybind11.h"
#include "pybind11/stl.h"
#include "pybind11/numpy.h"
#include "torch/script.h"

#include "decoder/brain_speech_decoder.h"
#include "utils/log.h"

namespace py = pybind11;

namespace wenet {

// Wrapper function to conver np array into torch tensor
void DecodeNumpy(BrainSpeechDecoder &decoder,
                 const py::array_t<float, py::array::c_style | py::array::forcecast> &input,
                 const py::array_t<float, py::array::c_style | py::array::forcecast> &log_priors_input,
                 const float blank_penalty) {
    auto input_info = input.request();
    auto log_priors_info = log_priors_input.request();
    CHECK(input_info.ndim == 2);
    CHECK(log_priors_info.ndim == 2);

    float *input_data = static_cast<float *>(input_info.ptr);
    float *log_priors_data = static_cast<float *>(log_priors_info.ptr);
    torch::Tensor logits = torch::from_blob(
        input_data, {input_info.shape[0], input_info.shape[1]}, torch::kFloat32);
    torch::Tensor log_priors = torch::from_blob(
        log_priors_data, {log_priors_info.shape[0], log_priors_info.shape[1]}, torch::kFloat32);

    auto log_probs = torch::log_softmax(logits, -1);
    log_probs = log_probs - log_priors;
    auto blank_log_probs = log_probs.index({torch::indexing::Slice(),
                                            torch::indexing::Slice(0, 1)});
    log_probs.index_put_({torch::indexing::Slice(),
                          torch::indexing::Slice(0, 1)}, blank_log_probs - blank_penalty);
    decoder.Decode(log_probs);
}

PYBIND11_MODULE(lm_decoder, m) {
    py::class_<DecodeOptions, std::shared_ptr<DecodeOptions> >(m, "DecodeOptions")
        .def(py::init<int, int, float, float, float, float, float, int>());

    py::class_<DecodeResource, std::shared_ptr<DecodeResource> >(m, "DecodeResource")
        .def(py::init<const std::string &, const std::string &, const std::string &, const std::string &, const std::string &>());

    py::class_<DecodeResult>(m, "DecodeResult")
        .def_readonly("ac_score", &DecodeResult::ac_score)
        .def_readonly("lm_score", &DecodeResult::lm_score)
        .def_readonly("sentence", &DecodeResult::sentence);

    py::class_<BrainSpeechDecoder>(m, "BrainSpeechDecoder")
        .def(py::init<std::shared_ptr<DecodeResource>, std::shared_ptr<DecodeOptions> >())
        .def("SetOpt", &BrainSpeechDecoder::SetOpt)
        .def("Decode", &BrainSpeechDecoder::Decode)
        .def("Rescore", &BrainSpeechDecoder::Rescore)
        .def("Reset", &BrainSpeechDecoder::Reset)
        .def("FinishDecoding", &BrainSpeechDecoder::FinishDecoding)
        .def("DecodedSomething", &BrainSpeechDecoder::DecodedSomething)
        .def("result", &BrainSpeechDecoder::result);

    m.def("DecodeNumpy", &DecodeNumpy);
}

}  // namespace wenet
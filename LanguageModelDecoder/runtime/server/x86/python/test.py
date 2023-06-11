import os

import numpy as np
import lm_decoder

decode_opts = lm_decoder.DecodeOptions(
    7000,   # max_active
    200,    # min_active
    17.,    # beam 
    8.,     # lattice_beam
    1.0,    # acoustic_scale
    0.98,   # ctc_blank_skip_threshold
    10      # nbest
)

model_path = '/oak/stanford/groups/shenoy/stfan/code/nptlrig2/LanguageModelDecoder/examples/handwriting/s0/3gram_no_prune/data/lang_test'
decode_resource = lm_decoder.DecodeResource(
    os.path.join(model_path, 'TLG.fst'),
    "",
    "",
    os.path.join(model_path, 'words.txt'),
    ""
)
decoder = lm_decoder.BrainSpeechDecoder(decode_resource, decode_opts)

# Load handwriting RNN logits output
logits = np.load('test_logits.npy')
print(logits.shape)

# Rearrange logits to Kaldi character order
# [ctc_blank, ">", ",", "?", "~", "'", a, b, ..., z]
char_range = list(range(0, 26))
logits = logits[:, :, [31] + [26, 27, 30, 29, 28] + char_range]

# Decode
for i in range(logits.shape[0]):
    lm_decoder.DecodeNumpy(decoder, logits[i])
    decoder.FinishDecoding()
    if len(decoder.result()) > 0:
        print(decoder.result()[0].sentence)
    else:
        print("No result")
    decoder.Reset()

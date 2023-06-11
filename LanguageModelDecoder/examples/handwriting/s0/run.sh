#!/bin/bash

. ./path.sh || exit 1;

stage=0
dict_type=char # char or phn
output_dir=$1

set -e
set -u
set -o pipefail

if [ ${stage} -le 0 ]; then
    # Build LM
    local/build_lm.sh \
        /oak/stanford/groups/shenoy/stfan/data/openwebtext/openwebtext2/formatted_webtext.txt \
        $output_dir/data/local/lm \
        $dict_type \
        3 0 \
        /oak/stanford/groups/shenoy/stfan/data/webtext/dict_chars
fi

if [ ${stage} -le 1 ]; then
    # Prepare L.fst
    local/prepare_dict_ctc.sh $output_dir/data/local/lm $output_dir/data/local/dict_phn
    tools/fst/ctc_compile_dict_token.sh $output_dir/data/local/dict_phn $output_dir/data/local/lang_phn_tmp $output_dir/data/lang_phn
fi

if [ ${stage} -le 2 ]; then
    # Build TLG decoding graph
    tools/fst/make_tlg.sh $output_dir/data/local/lm $output_dir/data/lang_phn $output_dir/data/lang_test
fi


# Commands for testing WER:
#GLOG_v=1 GLOG_logtostderr=1 ./brain_speech_decoder_main \
#    -data_path /home/cfan/logits.npy \
#    -fst_path ../../../../examples/brainspeech/s0/data/lang_test/TLG.fst \
#    -dict_path ../../../../examples/brainspeech/s0/data/lang_test/words.txt \
#    -beam 17 \
#    -lattice_beam 8 \
#    -blank_skip_thresh 0.98 \
#    -acoustic_scale 1.2 \
#    -rescore_lm_fst_path ../../../../examples/brainspeech/s0/data/lang_test/G_no_prune.fst \
#    -lm_fst_path ../../../../examples/brainspeech/s0/data/lang_test/G.fst \
#    -result test_rescore_as12.hyp

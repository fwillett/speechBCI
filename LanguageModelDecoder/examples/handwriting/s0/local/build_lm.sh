#!/bin/bash

lm_src=$1
lm_tgt_dir=$2
dict_type=$3
lm_order=$4
prune_threshold=$5
dict=$6

[ ! -f $dict ] && echo "No such file $dict" && exit 1;

# Check SRILM tools
if ! which ngram-count > /dev/null; then
    echo "srilm tools are not found, please download it and install it from: "
    echo "http://www.speech.sri.com/projects/srilm/download.html"
    echo "Then add the tools to your PATH"
    exit 1
fi

mkdir -p $lm_tgt_dir || exit 1;
echo $lm_tgt_dir

if [ $dict_type == 'phn' ]; then
  # Remove stress markers
  python local/remove_stress_marker.py \
    $dict $lm_tgt_dir/dict
  dict=$lm_tgt_dir/dict
elif [ $dict_type == 'char' ]; then
  cp $dict $lm_tgt_dir/dict
fi

# Unique words
cat $dict | awk '{print $1}' | uniq  > $lm_tgt_dir/lexicons.txt

# 3-gram LM
ngram-count -debug 1 -order $lm_order -wbdiscount -interpolate \
  -unk -map-unk "<unk>" -limit-vocab -vocab $lm_tgt_dir/lexicons.txt \
  -text $lm_src -lm $lm_tgt_dir/lm_orig.arpa

# Prune LM
if [ $prune_threshold ==  "0" ]; then
  ln -sf lm_orig.arpa $lm_tgt_dir/lm.arpa
else
  ngram -prune $prune_threshold -order $lm_order -lm $lm_tgt_dir/lm_orig.arpa -write-lm $lm_tgt_dir/lm_pruned.arpa
  ln -sf lm_pruned.arpa $lm_tgt_dir/lm.arpa
fi

#rm $lm_tgt_dir/webTextSentences_uppercase.txt

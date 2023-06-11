#!/bin/bash

# Parameters
#SBATCH --cpus-per-task=1
#SBATCH --job-name=lm
#SBATCH --mail-type=ALL
#SBATCH --mem=32GB
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --open-mode=append
#SBATCH --partition=shenoy,owners,henderj
#SBATCH --signal=USR1@120
#SBATCH --time=2880

export PATH=$PATH:/oak/stanford/groups/shenoy/stfan/code/nptlrig2/LanguageModelDecoder/srilm-1.7.3/bin/i686-m64/
ml gcc/10.1.0

. path.sh

lm_dir=lm_order_exp/5gram/data/local/lm/
tgt_lang=lm_order_exp/5gram/data/lang_test

#ngram -prune 4e-11 -order 5 -lm $lm_dir/lm_orig.arpa -write-lm $lm_dir/lm_pruned_4e-11.arpa

cat ${lm_dir}/lm_pruned_4e-11.arpa | \
   grep -v '<s> <s>' | \
   grep -v '</s> <s>' | \
   grep -v '</s> </s>' | \
   grep -v -i '<unk>' | \
   grep -v -i '<spoken_noise>' | \
   arpa2fst --read-symbol-table=$tgt_lang/words.txt --keep-symbols=true - | fstprint | \
   tools/fst/eps2disambig.pl | tools/fst/s2eps.pl | fstcompile --isymbols=$tgt_lang/words.txt \
     --osymbols=$tgt_lang/words.txt  --keep_isymbols=false --keep_osymbols=false | \
    fstrmepsilon | fstarcsort --sort_type=ilabel > $tgt_lang/G_pruned_4e-11.fst

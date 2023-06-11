#!/bin/bash

# Parameters
#SBATCH --cpus-per-task=1
#SBATCH --job-name=lm
#SBATCH --mail-type=ALL
#SBATCH --mem=32GB
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --open-mode=append
#SBATCH --partition=shenoy,owners
#SBATCH --signal=USR1@120
#SBATCH --time=2880

export PATH=$PATH:/oak/stanford/groups/shenoy/stfan/code/nptlrig2/LanguageModelDecoder/srilm-1.7.3/bin/i686-m64/
ml gcc/10.1.0

mkdir -p $1/data/local
#ln -sf $PWD/openwebtext2/3gram_prune_1e-9/data/local/lm $1/data/local/lm
./run.sh $1 $2 $3 $4 $5 $6 $7

# Brain Speech

## Setup compiler
```
ml load gcc/10.1.0
```

## Install SRILM
```
cd ../../../srilm-1.7.3
export SRILM=$PWD
make MAKE_PIC=yes World
make cleanest
export PATH=$PATH:$PWD/bin/i686-m64
```

## Build runtime
Follow the instructions in `../../../README.md`

## Build TLG Graph
`run.sh output_dir`

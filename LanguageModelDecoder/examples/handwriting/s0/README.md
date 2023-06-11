# Brain Speech

## Install SRILM
* Downlaod source code from http://www.speech.sri.com/projects/srilm/download.html
* Build with the following commands:
```
mkdir srilm-1.7.3
tar xf srilm-1.7.3.tar.gz -C srilm-1.7.3
cd srilm-1.7.3
export SRILM=$PWD
make MAKE_PIC=yes World
make cleanest
```
* Include `srilm-1.7.3/bin/i686-m64` in your `PATH`

## Prepare Text Corpora for Language Model


## Build TLG Graph
`run.sh output_dir`
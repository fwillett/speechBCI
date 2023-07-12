# Introduction
This is the repo for langauage model decoder. Codes are based on [WeNet](https://github.com/wenet-e2e/wenet) and [Kaldi](https://github.com/kaldi-asr/kaldi).

# Dependencies
```
CMake >= 3.14
gcc >= 10.1
pytorch==1.13.1
```

Please note that this library uses libtorch 1.13.1. If you have other versions of pytorch installed, you may need to uninstall them first and then install the correct version.


# Instructions for build and run the language model decoder

If you have downloaded the WFST decoding graph, you can skip the first and second steps and go to the [third step](#build-decoder-runtime).


### Step 1: Build binaries for building language model:
Build SRILM:
  ```
  cd srilm-1.7.3
  export SRILM=$PWD
  make -j8 MAKE_PIC=yes World && make -j8 cleanest
  ```

Build openfst, kaldi and other stuff:
  ```
  cd runtime/server/x86
  mkdir build && cd build
  cmake ..
  make -j8
  ```

### Step 2: Build language model and WFST decoding graph:

Run this [notebook](../AnalysisExamples/buildLanguageModel.ipynb).


### Step 3: Build decoder runtime

```
cd runtime/server/x86
python setup.py install
```

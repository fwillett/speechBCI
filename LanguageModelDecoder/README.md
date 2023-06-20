# Brain Speech Decoder
Based on [WeNet](https://github.com/wenet-e2e/wenet) and [Kaldi](https://github.com/kaldi-asr/kaldi)

# Dependencies
```
CMake >= 3.14
```

# Build Decoder Runtime
If you are on Sherlock, set up the build environemnt with the following commands:
```
ml cmake
ml gcc/10.1.0
export CC=/share/software/user/open/gcc/10.1.0/bin/gcc
export CXX=/share/software/user/open/gcc/10.1.0/bin/g++
```

Build decoder runtime:
```
cd runtime/server/x86
python setup.py install
```

# Run Decoder
## Run python
See `runtime/server/x86/python/test.py`


# Build Language Model
1. First, build binaries for building language model:
    1. Build SRILM:
      ```
      cd srilm-1.7.3
      export SRILM=$PWD
      make MAKE_PIC=yes World
      make cleanest
      export PATH=$PATH:$PWD/bin/i686-m64
      ```

    2. Build openfst and other stuff:
      ```
      cd runtime/server/x86
      mkdir build
      cd build
      cmake ..
      make -j8
      ```

2. Build speech LM:
  ```
  cd examples/speech/s0/
  sbatch run_sbatch.sh output_dir dict_path train_corpus sil_prob
  ```



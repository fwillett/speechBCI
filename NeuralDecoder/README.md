# Neural Sequence Decoder

## Installation

```
pip install -e .
```

## Handwriting
TODO

## Speech

### With simulated speech data
1. Convert data to tfrecords with `notebooks/speech/formatSimulatedOLData.ipynb`
2. Training:
    - Run it locally (on your own machine or if you have logged in to a Sherlock compute node): `scripts/speech/run_simulated_local.sh`
    - Run it on Sherlock (i.e. you want to submit it to Sherlock's Slurm cluster): `scripts/speech/run_simulated_slurm.sh`
    - Change the `dataset.dataDir` and `outputDir` in the scripts to point to your data and output directories.
3. Monitor training: `tensorboard --logdir=your/output/dir --port your_forwarding_port`
4. Inference notebook: `notebooks/speech/inferenceTest.ipynb`
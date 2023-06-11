from setuptools import setup, find_packages

setup(
    name='neural_decoder',
    version='0.0.1',
    packages=find_packages(include=['neuralDecoder']),
    install_requires=[
        'tensorflow-gpu==2.10.0',
        'hydra-core==1.1.0',
        'hydra-submitit-launcher==1.1.5',
        'transformers==4.23.1',
        'pandas',
	'numba',
        'jupyterlab',
        'ipywidgets',
        'tqdm',
	'wandb',
	'seaborn',
	'edit-distance',
        'g2p_en==2.1.0'
    ]
)

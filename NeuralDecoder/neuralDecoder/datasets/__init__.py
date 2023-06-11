from .speechDataset import SpeechDataset

def getDataset(datasetName):
    if datasetName == 'speech':
        return SpeechDataset
    else:
        raise ValueError('Dataset not found')
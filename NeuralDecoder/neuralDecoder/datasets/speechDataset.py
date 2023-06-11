import pathlib
import random
import numpy as np
import tensorflow as tf

PHONE_DEF = [
    'AA', 'AE', 'AH', 'AO', 'AW',
    'AY', 'B',  'CH', 'D', 'DH',
    'EH', 'ER', 'EY', 'F', 'G',
    'HH', 'IH', 'IY', 'JH', 'K',
    'L', 'M', 'N', 'NG', 'OW',
    'OY', 'P', 'R', 'S', 'SH',
    'T', 'TH', 'UH', 'UW', 'V',
    'W', 'Y', 'Z', 'ZH'
]

PHONE_DEF_SIL = [
    'AA', 'AE', 'AH', 'AO', 'AW',
    'AY', 'B',  'CH', 'D', 'DH',
    'EH', 'ER', 'EY', 'F', 'G',
    'HH', 'IH', 'IY', 'JH', 'K',
    'L', 'M', 'N', 'NG', 'OW',
    'OY', 'P', 'R', 'S', 'SH',
    'T', 'TH', 'UH', 'UW', 'V',
    'W', 'Y', 'Z', 'ZH', 'SIL'
]

CHANG_PHONE_DEF = [
    'AA', 'AE', 'AH', 'AW',
    'AY', 'B',  'D', 'DH',
    'EH', 'ER', 'EY', 'F', 'G',
    'HH', 'IH', 'IY', 'K',
    'L', 'M', 'N', 'NG', 'OW',
    'P', 'R', 'S',
    'T', 'TH', 'UH', 'UW', 'V',
    'W', 'Y', 'Z'
]

CONSONANT_DEF = ['CH', 'SH', 'JH', 'R', 'B',
                 'M',  'W',  'V',  'F', 'P',
                 'D',  'N',  'L',  'S', 'T',
                 'Z',  'TH', 'G',  'Y', 'HH',
                 'K', 'NG', 'ZH', 'DH']
VOWEL_DEF = ['EY', 'AE', 'AY', 'EH', 'AA',
             'AW', 'IY', 'IH', 'OY', 'OW',
             'AO', 'UH', 'AH', 'UW', 'ER']

SIL_DEF = ['SIL']

class SpeechDataset():
    def __init__(self,
                 rawFileDir,
                 nInputFeatures,
                 nClasses,
                 maxSeqElements,
                 bufferSize,
                 syntheticFileDir=None,
                 syntheticMixingRate=0.33,
                 subsetSize=-1,
                 labelDir=None,
                 timeWarpSmoothSD=0.0,
                 timeWarpNoiseSD=0.0,
                 chanIndices=None
                 ):

        self.rawFileDir = rawFileDir
        self.nInputFeatures = nInputFeatures
        self.nClasses = nClasses
        self.maxSeqElements = maxSeqElements
        self.bufferSize = bufferSize
        self.syntheticFileDir = syntheticFileDir
        self.syntheticMixingRate = syntheticMixingRate
        self.timeWarpSmoothSD = timeWarpSmoothSD
        self.timeWarpNoiseSD = timeWarpNoiseSD
        self.subsetSize = subsetSize
        self.chanIndices = chanIndices
        
    def build(self, batchSize, isTraining):
        def _loadDataset(fileDir):
            files = sorted([str(x) for x in pathlib.Path(fileDir).glob("*.tfrecord")])
            if isTraining:
                random.shuffle(files)

            dataset = tf.data.TFRecordDataset(files)
            return dataset

        print(f'Load data from {self.rawFileDir}')
        rawDataset = _loadDataset(self.rawFileDir)
        if self.syntheticFileDir and self.syntheticMixingRate > 0:
            print(f'Load data from {self.syntheticFileDir}')
            syntheticDataset = _loadDataset(self.syntheticFileDir)
            dataset = tf.data.experimental.sample_from_datasets(
                [rawDataset.repeat(), syntheticDataset.repeat()],
                weights=[1.0 - self.syntheticMixingRate, self.syntheticMixingRate])
        else:
            dataset = rawDataset

        datasetFeatures = {
            "inputFeatures": tf.io.FixedLenSequenceFeature([self.nInputFeatures], tf.float32, allow_missing=True),
            #"classLabelsOneHot": tf.io.FixedLenSequenceFeature([self.nClasses+1], tf.float32, allow_missing=True),
            "newClassSignal": tf.io.FixedLenSequenceFeature([], tf.float32, allow_missing=True),
            "ceMask": tf.io.FixedLenSequenceFeature([], tf.float32, allow_missing=True),
            "seqClassIDs": tf.io.FixedLenFeature((self.maxSeqElements), tf.int64),
            "nTimeSteps": tf.io.FixedLenFeature((), tf.int64),
            "nSeqElements": tf.io.FixedLenFeature((), tf.int64),
            "transcription": tf.io.FixedLenFeature((self.maxSeqElements), tf.int64)
        }

        if self.timeWarpNoiseSD>0 and self.timeWarpSmoothSD>0:
            from scipy.ndimage.filters import gaussian_filter1d
            inp = np.zeros([200])
            inp[int(len(inp)/2)] = 1
            gaussKernel = gaussian_filter1d(inp, self.timeWarpSmoothSD)

            validIdx = np.argwhere(gaussKernel>0.001)
            gaussKernel = gaussKernel[validIdx]
            gaussKernel = np.squeeze(gaussKernel/np.sum(gaussKernel))

            timeWarpNoiseSD= self.timeWarpNoiseSD

            def parseDatasetFunctionWarp(exampleProto):
                dat = tf.io.parse_single_example(exampleProto, datasetFeatures)

                warpDat = {}
                warpDat['seqClassIDs'] = dat['seqClassIDs']
                warpDat['nSeqElements'] = dat['nSeqElements']
                warpDat['transcription'] = dat['transcription']

                whiteNoise = tf.random.normal([dat['nTimeSteps']*2], mean=0, stddev=timeWarpNoiseSD)
                rateNoise = tf.nn.conv1d(whiteNoise[tf.newaxis,:,tf.newaxis],
                                         gaussKernel[:,np.newaxis,np.newaxis].astype(np.float32), 1, 'SAME')

                rateNoise = rateNoise[0,:,0]
                toSum = tf.ones([dat['nTimeSteps']*2], dtype=tf.float32) + rateNoise
                toSum = tf.nn.relu(toSum)

                warpFun = tf.cumsum(toSum)
                resampleIdx = tf.cast(warpFun, dtype=tf.int32)
                resampleIdx = resampleIdx[resampleIdx<tf.cast(dat['nTimeSteps'],dtype=tf.int32)]

                warpDat['nTimeSteps'] = tf.cast(tf.reduce_sum(tf.cast(resampleIdx>-1,dtype=tf.int32)), dtype=tf.int32)
                warpDat['inputFeatures'] = tf.gather(dat['inputFeatures'], resampleIdx, axis=0)
                if self.chanIndices is not None:
                    selectChans = tf.gather(warpDat['inputFeatures'], tf.constant(self.chanIndices),axis=-1)
                    paddings = [[0, 0], [0, 256-tf.shape(selectChans)[-1]]]
                    warpDat['inputFeatures'] = tf.pad(selectChans, paddings, 'CONSTANT',constant_values=0)
                warpDat['newClassSignal'] = tf.gather(dat['newClassSignal'], resampleIdx, axis=0)
                warpDat['ceMask'] = tf.gather(dat['ceMask'], resampleIdx, axis=0)

                return warpDat

            dataset = dataset.map(parseDatasetFunctionWarp, num_parallel_calls=tf.data.AUTOTUNE)

        else:
            def parseDatasetFunctionSimple(exampleProto):
                dat = tf.io.parse_single_example(exampleProto, datasetFeatures)
                if self.chanIndices is not None:
                    newDat = {}
                    newDat['seqClassIDs'] = dat['seqClassIDs']
                    newDat['nSeqElements'] = dat['nSeqElements']
                    newDat['transcription'] = dat['transcription']
                    newDat['nTimeSteps'] = dat['nTimeSteps']
                    newDat['newClassSignal'] = dat['newClassSignal']
                    newDat['ceMask'] = dat['ceMask']
                    print(dat['inputFeatures'])
                    selectChans = tf.gather(dat['inputFeatures'], tf.constant(self.chanIndices),axis=-1)
                    paddings = [[0, 0], [0, 256-tf.shape(selectChans)[-1]]]
                    newDat['inputFeatures'] = tf.pad(selectChans, paddings, 'CONSTANT',constant_values=0)
                    print(tf.shape(newDat['inputFeatures']))

                    return newDat
                else:
                    return dat
            dataset = dataset.map(parseDatasetFunctionSimple, num_parallel_calls=tf.data.AUTOTUNE)

        if isTraining:
            # Use all elements to adapt normalization layer
            datasetForAdapt = dataset.map(lambda x: x['inputFeatures'] + 0.001,
                num_parallel_calls=tf.data.AUTOTUNE)
            
            # Take a subset of the data if specified
            if self.subsetSize > 0:
                dataset = dataset.take(self.subsetSize)

            # Shuffle and transform data if training
            dataset = dataset.shuffle(self.bufferSize)
            if self.syntheticMixingRate == 0:
                dataset = dataset.repeat()
            dataset = dataset.padded_batch(batchSize)
            dataset = dataset.prefetch(tf.data.AUTOTUNE)
            
            

            return dataset, datasetForAdapt
        else:
            dataset = dataset.padded_batch(batchSize)
            dataset = dataset.prefetch(tf.data.AUTOTUNE)

            return dataset

import scipy.io
import numpy as np
import tensorflow as tf
import os
from pathlib import Path
import matplotlib.pyplot as plt
from g2p_en import G2p
import re
from neuralDecoder.datasets.speechDataset import PHONE_DEF, VOWEL_DEF, CONSONANT_DEF, SIL_DEF, PHONE_DEF_SIL
        
def makeTFRecordsFromCompetitionFiles(sessionName, dataPath, tfRecordFolder):
    
    partNames = ['train','test','competitionHoldOut']
    
    for partIdx in range(len(partNames)):
        sessionPath = dataPath + '/' + partNames[partIdx] + '/' + sessionName + '.mat'
        if not os.path.isfile(sessionPath):
            continue
            
        dat = scipy.io.loadmat(sessionPath)

        input_features = []
        transcriptions = []
        frame_lens = []
        block_means = []
        block_stds = []
        n_trials = dat['sentenceText'].shape[0]

        #collect area 6v tx1 and spikePow features
        for i in range(n_trials):    
            #get time series of TX and spike power for this trial
            #first 128 columns = area 6v only
            features = np.concatenate([dat['tx1'][0,i][:,0:128], dat['spikePow'][0,i][:,0:128]], axis=1)

            sentence_len = features.shape[0]
            sentence = dat['sentenceText'][i].strip()

            input_features.append(features)
            transcriptions.append(sentence)
            frame_lens.append(sentence_len)

        #block-wise feature normalization
        blockNums = np.squeeze(dat['blockIdx'])
        blockList = np.unique(blockNums)
        blocks = []
        for b in range(len(blockList)):
            sentIdx = np.argwhere(blockNums==blockList[b])
            sentIdx = sentIdx[:,0].astype(np.int32)
            blocks.append(sentIdx)

        for b in range(len(blocks)):
            feats = np.concatenate(input_features[blocks[b][0]:(blocks[b][-1]+1)], axis=0)
            feats_mean = np.mean(feats, axis=0, keepdims=True)
            feats_std = np.std(feats, axis=0, keepdims=True)
            for i in blocks[b]:
                input_features[i] = (input_features[i] - feats_mean) / (feats_std + 1e-8)

        #convert to tfRecord file
        session_data = {
            'inputFeatures': input_features,
            'transcriptions': transcriptions,
            'frameLens': frame_lens
        }

        folderName = tfRecordFolder+'/'+partNames[partIdx]
        convertToTFRecord(session_data, 
                          folderName,
                          np.arange(0,len(input_features)).astype(np.int32))
        
def convertToTFRecord(sessionData, recordFolder, partIdx):

    nClasses = 31
    maxSeqLen = 500
    g2p = G2p()
    
    def _floats_feature(value):
        return tf.train.Feature(float_list=tf.train.FloatList(value=value))

    def _ints_feature(value):
        return tf.train.Feature(int64_list=tf.train.Int64List(value=value))

    def _convert_to_ascii(text):
        return [ord(char) for char in text]

    def phoneToId(p):
        return PHONE_DEF_SIL.index(p)

    saveDir = Path(recordFolder)
    saveDir.mkdir(parents=True, exist_ok=True)
    print(partIdx)

    with tf.io.TFRecordWriter(str(saveDir.joinpath('chunk_0.tfrecord'))) as writer:
        for trialIdx in partIdx:
            inputFeats = sessionData['inputFeatures'][trialIdx]

            classLabels = np.zeros([inputFeats.shape[0], nClasses]).astype(np.float32)
            newClassSignal = np.zeros([inputFeats.shape[0], 1]).astype(np.float32)
            seqClassIDs = np.zeros([maxSeqLen]).astype(np.int32)

            thisTranscription = sessionData['transcriptions'][trialIdx]

            # Remove punctuation
            thisTranscription = re.sub(r'[^a-zA-Z\- \']', '', thisTranscription)
            thisTranscription = thisTranscription.replace('--', '').lower()
            phonemes = []
            if len(thisTranscription) == 0:
                phonemes = SIL_DEF
            else:
                for p in g2p(thisTranscription):
                    if p==' ':
                        phonemes.append('SIL')

                    p = re.sub(r'[0-9]', '', p)  # Remove stress
                    if re.match(r'[A-Z]+', p):  # Only keep phonemes
                        phonemes.append(p)

                #add one SIL symbol at the end so there's one at the end of each word
                phonemes.append('SIL')

            seqLen = len(phonemes)
            seqClassIDs[0:seqLen] = [phoneToId(p) + 1 for p in phonemes]
            print(phonemes)

            print(thisTranscription)
            ceMask = np.zeros([inputFeats.shape[0]]).astype(np.float32)
            ceMask[0:sessionData['frameLens'][trialIdx]] = 1

            paddedTranscription = np.zeros([maxSeqLen]).astype(np.int32)
            paddedTranscription[0:len(thisTranscription)] = np.array(_convert_to_ascii(thisTranscription))

            feature = {'inputFeatures': _floats_feature(np.ravel(inputFeats).tolist()),
                'classLabelsOneHot': _floats_feature(np.ravel(classLabels).tolist()),
                'newClassSignal': _floats_feature(np.ravel(newClassSignal).tolist()),
                'seqClassIDs': _ints_feature(seqClassIDs),
                'nTimeSteps': _ints_feature([sessionData['frameLens'][trialIdx]]),
                'nSeqElements': _ints_feature([seqLen]),
                'ceMask': _floats_feature(np.ravel(ceMask).tolist()),
                'transcription': _ints_feature(paddedTranscription)}

            #print(paddedTranscription[0:10])
            print(seqClassIDs[0:10])
            example = tf.train.Example(features=tf.train.Features(feature=feature))
            writer.write(example.SerializeToString())    

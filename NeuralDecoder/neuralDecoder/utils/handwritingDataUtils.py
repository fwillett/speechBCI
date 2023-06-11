import os
import re
from pathlib import Path

import numpy as np
import scipy.io
import tensorflow as tf
from g2p_en import G2p

from neuralDecoder.datasets.handwritingDataset import CHAR_DEF
from neuralDecoder.datasets.speechDataset import PHONE_DEF, VOWEL_DEF, CONSONANT_DEF, SIL_DEF, PHONE_DEF_SIL
from neuralDecoder.realtimeRNNDecoderRedis import FeatureStats

def _floats_feature(value):
    return tf.train.Feature(float_list=tf.train.FloatList(value=value))

def _ints_feature(value):
    return tf.train.Feature(int64_list=tf.train.Int64List(value=value))

def _convert_to_ascii(text):
    return [ord(char) for char in text]

def formatSessionData(blocks, trialsToRemove, dataDir, channels=192, task='HandwritingTask',
                      includeSpikePower=False, globalStd=False, spikePowerMax=10000, zscoreData=True):
    # trialsToRemove: {block_num: [trial_0, trial_1, ...]}
    #                 Use session document block number
    #                 Use session document trial number - 1 (In session trial number is 1-based, here is 0-based)
    inputFeatures = []
    rawInputFeatures = []
    transcriptions = []
    pseudoLabels = []
    frameLens = []
    trialTimes = []
    blockMeans = []
    blockStds = []
    blockList = []

    for b in blocks:
        redisFile = sorted([str(x) for x in Path(dataDir, 'RedisMat').glob('*('+str(b)+').mat')])
        redisFile = redisFile[-1]
        print(redisFile)
        redisDat = scipy.io.loadmat(redisFile)

        taskFile = sorted([str(x) for x in Path(dataDir, 'TaskData', task).glob('*('+str(b)+').mat')])
        taskFile = taskFile[-1]
        print(taskFile)
        taskDat = scipy.io.loadmat(taskFile)

        trlStart = np.logical_and(taskDat['timeSeriesData'][0:-1,2]==0, taskDat['timeSeriesData'][1:,2]==1)
        trlEnd = np.logical_and(taskDat['timeSeriesData'][0:-1,2]==1, taskDat['timeSeriesData'][1:,2]==0)

        trlStart = np.squeeze(np.argwhere(trlStart))
        trlEnd = np.squeeze(np.argwhere(trlEnd))

        # Edge case when block only has 1 trial
        if trlStart.size == 1:
            trlStart = np.array([trlStart])
        if trlEnd.size == 1:
            trlEnd = np.array([trlEnd])

        if len(trlEnd)==0:
            #closed-loop button press mode uses state 1->3 for trl end (go state -> end-trial state)
            trlEnd = np.logical_and(taskDat['timeSeriesData'][0:-1,2]==1, taskDat['timeSeriesData'][1:,2]==3)
            trlEnd = np.squeeze(np.argwhere(trlEnd))

        blockStartIdx = len(inputFeatures)
        for x in range(len(trlStart)):
            startTime = taskDat['timeSeriesData'][trlStart[x],1]
            endTime = taskDat['timeSeriesData'][trlEnd[x],1]

            if b in trialsToRemove and x in trialsToRemove[b]:
                print(f"Remove block {b}'s trial {x}")
                continue

            trialTimes.append(endTime - startTime)

            startTimeStep = np.argmin(np.abs(redisDat['binnedNeural_xpcClock']-startTime))
            endTimeStep = np.argmin(np.abs(redisDat['binnedNeural_xpcClock']-endTime))

            #validStartTimes = redisDat['binnedNeural_xpcClock'].copy()
            #validStartTimes = validStartTimes[validStartTimes>startTime]

            #validEndTimes = redisDat['binnedNeural_xpcClock'].copy()
            #validEndTimes = validEndTimes[validEndTimes>startTime]

            #redisLen = redisDat['binnedNeural_xpcClock'].shape[1]
            #startTimeStep = np.argmin(np.abs(validStartTimes-startTime)) + (redisLen-len(validStartTimes))
            #endTimeStep = np.argmin(np.abs(validEndTimes-endTime)) + (redisLen-len(validEndTimes)) + 2

            newInputFeatures = redisDat['binnedNeural'][startTimeStep:endTimeStep,:].astype(np.float32)
            if includeSpikePower:
                #limit to max 10000 to combat huge noise spikes
                tmp = redisDat['binnedNeural_hlfp'][startTimeStep:endTimeStep,:].copy()
                tmp[tmp>spikePowerMax]=spikePowerMax
                newInputFeatures = np.concatenate([newInputFeatures, tmp], axis=1)

            newTranscription = taskDat['cues'][x,0][0]
            newInputFeatures = newInputFeatures[:, :channels]

            rawInputFeatures.append(newInputFeatures)
            inputFeatures.append(newInputFeatures)
            transcriptions.append(newTranscription)
            frameLens.append(newInputFeatures.shape[0])
            blockList.append(b)
        if 'ngramDecoderFinalOutput' in redisDat:
            for i, x in enumerate(redisDat['ngramDecoderFinalOutput'][0]):
                if len(x) == 0:
                    pseudoLabels.append('')  # empty decoded label
                elif x == 0:
                    continue
                else:
                    pseudoLabels.append(x[0])

        blockEndIdx = len(inputFeatures)
        block = np.concatenate(inputFeatures[blockStartIdx:blockEndIdx], 0)
        blockMean = np.mean(block, axis=0, keepdims=True).astype(np.float32)
        blockMeans.append(blockMean)
        blockStd = np.std(block, axis=0, keepdims=True).astype(np.float32)
        blockStds.append(blockStd)

        if zscoreData:
            for i in range(blockStartIdx, blockEndIdx):
                if globalStd:
                    inputFeatures[i] = (inputFeatures[i].astype(np.float32) - blockMean)
                else:
                    inputFeatures[i] = (inputFeatures[i].astype(np.float32) - blockMean) / (blockStd + 1e-8)

    allDat = block = np.concatenate(inputFeatures, 0)
    gStd = np.std(block, axis=0, keepdims=True).astype(np.float32)
    if globalStd and zscoreData:
        for i in range(len(inputFeatures)):
            inputFeatures[i] = (inputFeatures[i].astype(np.float32)) / (gStd + 1e-8)

    return {
        'inputFeatures': inputFeatures,
        'rawInputFeatures': rawInputFeatures,
        'transcriptions': transcriptions,
        'trialTimes': trialTimes,
        'frameLens': frameLens,
        'blockList': blockList,
        'blockMeans': blockMeans,
        'blockStds': blockStds,
        'globalStd': gStd,
        'pseudoLabels': pseudoLabels,
    }

def formatSessionDataForRelease(blocks, trialsToRemove, dataDir, channels=192, task='HandwritingTask', includeSpikePower=False):
   rawInputFeatures = []
   transcriptions = []
   frameLens = []
   trialTimes = []
   blockList = []
   neuralActivityTimeSeries = []
   xpcClockTimeSeries = []
   excludedTrials = []
   goCueTimes = []
   delayCueTimes = []

   for b in blocks:
       redisFile = sorted([str(x) for x in Path(dataDir, 'RedisMat').glob('*('+str(b)+').mat')])
       redisFile = redisFile[-1]
       print(redisFile)
       redisDat = scipy.io.loadmat(redisFile)

       taskFile = sorted([str(x) for x in Path(dataDir, 'TaskData', task).glob('*('+str(b)+').mat')])
       taskFile = taskFile[-1]
       taskDat = scipy.io.loadmat(taskFile)

       trlStart = np.logical_and(taskDat['timeSeriesData'][0:-1,2]==0, taskDat['timeSeriesData'][1:,2]==1)
       trlEnd = np.logical_and(taskDat['timeSeriesData'][0:-1,2]==1, taskDat['timeSeriesData'][1:,2]==0)

       trlStart = np.squeeze(np.argwhere(trlStart))
       trlEnd = np.squeeze(np.argwhere(trlEnd))

       neuralActivityTimeSeries.append(redisDat['binnedNeural'])
       xpcClockTimeSeries.append(np.squeeze(redisDat['binnedNeural_xpcClock']))

       for x in range(len(trlStart)):

           startTime = taskDat['timeSeriesData'][trlStart[x],1]
           endTime = taskDat['timeSeriesData'][trlEnd[x],1]

           if b in trialsToRemove and x in trialsToRemove[b]:
               print(f"Remove block {b}'s trial {x}")
               excludedTrials.append(True)
           else:
               excludedTrials.append(False)


           startTimeStep = np.argmin(np.abs(redisDat['binnedNeural_xpcClock']-startTime))
           endTimeStep = np.argmin(np.abs(redisDat['binnedNeural_xpcClock']-endTime))

           newInputFeatures = redisDat['binnedNeural'][startTimeStep:endTimeStep,:]
           if includeSpikePower:
                newInputFeatures = np.concatenate(
                    [newInputFeatures, redisDat['binnedNeural_hlfp'][startTimeStep:endTimeStep,:]],
                    axis=1)

           newTranscription = taskDat['cues'][x,0][0]

           newInputFeatures = newInputFeatures[:, :channels]

           goCueTimes.append(startTime)
           if x == 0:
               # delay cue is only present starting at trial 1
               # assume the trial 0 has delay cue time at 0
               # but this is an overestimate
               # TODO: Fix this
               delayCueTimes.append(0)
           delayCueTimes.append(endTime)
           trialTimes.append(endTime - startTime)
           rawInputFeatures.append(newInputFeatures)
           transcriptions.append(newTranscription)
           frameLens.append(newInputFeatures.shape[0])
           blockList.append(b)

   return {
       'neuralActivityCube': np.array(rawInputFeatures, dtype=object),  # (nTimeSteps, nChannels) * nTrials
       'sentencePrompt': np.array(transcriptions, dtype=object),  # (nTrials)
       'numTimeBinsPerSentence': np.array(frameLens),  # (nTrials)
       'blockList': np.array(blockList),  # (nTrials)
       'neuralActivityTimeSeries': np.array(neuralActivityTimeSeries, dtype=object),  # (nTimeSteps, nChannels) * nBlocks
       'xpcClockTimeSeries': np.array(xpcClockTimeSeries, dtype=object),  # (nTimeSteps) * nBlocks
       'excludedTrials': np.array(excludedTrials),  # (nTrials)
       'goCueTimes': np.array(goCueTimes),  # (nTrials)
       'delayCueTimes': np.array(delayCueTimes)  # (nTrials)
   }

def generateReleaseDataReadme(readmePath):
    content = \
        """
        This folder contains the recorded neural data for the handwriting task performed by T5 in one session.

        Follwing is a description of each field in the sentences.mat file, which contains all the task information
        and binned neural data (20ms bin size).

        nTrials: number of trials in the session
        nBlocks: number of blocks in the session
        nTimeSteps: number of time steps of a single trial or single block
        nChannels: number of recording channels

        sentences.mat:
            neuralActivityCube
                Shape: nTrials * [nTimeSteps, nChannels]:
                Description: A ragged array of binned firing rates.
                             Each array element is a single trial of shape [nTimeSteps, nChannels].
            sentencePrompt
                Shape: [nTrials]
                Description: An array where each element is the sentence prompt for each trial.
            numTimeBinsPerSentence
                Shape: [nTrials]
                Description: An array where each element is the number of time bins of each trial.
            blockList:
                Shape: [nTrials]
                Description: An array where each element is the block number of each trial.
            neuralActivityTimeSeries:
                Shape: nBlocks * [nTimeSteps, nChannels]
                Description: A ragged array of binned firing rates.
                             Each array element has shape [nTimeSteps, nChannels], which is recorded firing rates for the entire block.
            xpcClockTimeSeries:
                Shape: nBlocks * [nTimeSteps]
                Description: A ragged array of xpc clock times.
                             Each array element is the xpc clock time for each time bin of the block.
            excludedTrials:
                Shape: [nTrials]
                Description: An array where each element is a boolean indicating whether a trial is excluded.
            goCueTimes:
                Shape: [nTrials]
                Description: An array of go cue times for each trial.
            delayCueTimes:
                Shape: [nTrials]
                Description: An array of delay cue times for each trial.
        """

    readmePath.write_text(content)


def convertToTFRecord(sessionData, outputDir, trainTrials, testTrials,
                      convertToPhonemes=False,
                      vowelOnly=False,
                      consonantOnly=False, addInterWordSymbol=False, alreadyInPhonemes=False):

    partNames = ['train', 'test']
    partSets = [trainTrials, testTrials]
    nClasses = 31
    maxSeqLen = 500
    g2p = G2p()

    def charToId(char):
        return CHAR_DEF.index(char)

    def phoneToId(p):
        if addInterWordSymbol:
            return PHONE_DEF_SIL.index(p)
        elif vowelOnly:
            return VOWEL_DEF.index(p)
        elif consonantOnly:
            return CONSONANT_DEF.index(p)
        else:
            return PHONE_DEF.index(p)

    for pIter in range(len(partNames)):

        partIdx = partSets[pIter]
        saveDir = Path(outputDir, partNames[pIter])
        saveDir.mkdir(parents=True, exist_ok=True)

        with tf.io.TFRecordWriter(str(saveDir.joinpath('chunk_0.tfrecord'))) as writer:
            for trialIdx in partIdx:
                inputFeats = sessionData['inputFeatures'][trialIdx]

                classLabels = np.zeros([inputFeats.shape[0], nClasses]).astype(np.float32)
                newClassSignal = np.zeros([inputFeats.shape[0], 1]).astype(np.float32)
                seqClassIDs = np.zeros([maxSeqLen]).astype(np.int32)

                thisTranscription = sessionData['transcriptions'][trialIdx]
                if not convertToPhonemes:
                    seqLen = len(thisTranscription)
                    seqClassIDs[0:seqLen] = [charToId(c) + 1 for c in thisTranscription]
                elif alreadyInPhonemes:
                    thesePhones = thisTranscription.split(' ')
                    seqLen = len(thesePhones)
                    seqClassIDs[0:seqLen] = [phoneToId(p) + 1 for p in thesePhones]
                else:
                    # Remove punctuation
                    thisTranscription = re.sub(r'[^a-zA-Z\- \']', '', thisTranscription)
                    thisTranscription = thisTranscription.replace('--', '').lower()
                    phonemes = []
                    if len(thisTranscription) == 0:
                        phonemes = SIL_DEF
                    else:
                        for p in g2p(thisTranscription):
                            if addInterWordSymbol and p==' ':
                                phonemes.append('SIL')

                            p = re.sub(r'[0-9]', '', p)  # Remove stress
                            if re.match(r'[A-Z]+', p):  # Only keep phonemes
                                phonemes.append(p)
                            if vowelOnly:
                                phonemes = [p for p in phonemes if p in VOWEL_DEF]
                            if consonantOnly:
                                phonemes = [p for p in phonemes if p in CONSONANT_DEF]

                        #add one SIL symbol at the end so there's one at the end of each word
                        if addInterWordSymbol:
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


def normalizeWithAdaptiveMeanStd(feats, prevMean, prevStd, adaptMinTrials, adaptWindowSize, adaptStd=False):
    stats = FeatureStats(adaptWindowSize, prevMean, prevStd, adaptMinTrials, adaptStd)
    for i in range(len(feats)):
        rawFeats = feats[i].copy()
        feats[i] = (feats[i] - stats.mean[None, :]) / stats.std[None, :]
        stats.update(rawFeats)

    return feats

import numpy as np
import scipy.stats
from scipy.ndimage import gaussian_filter1d
from numba import njit
import matplotlib.pyplot as plt
import numpy as np
import tensorflow as tf
import neuralDecoder.utils.lmDecoderUtils as lmDecoderUtils
from omegaconf import OmegaConf
from neuralDecoder.neuralSequenceDecoder import NeuralSequenceDecoder
import os

@njit
def meanResamples(trlConcat, nResamples):
    resampleMeans = np.zeros((nResamples, trlConcat.shape[1], trlConcat.shape[2]))
    for rIdx in range(nResamples):
        resampleIdx = np.random.randint(0,trlConcat.shape[0],trlConcat.shape[0])
        resampleTrl = trlConcat[resampleIdx,:,:]
        resampleMeans[rIdx,:,:] = np.sum(resampleTrl, axis=0)/trlConcat.shape[0]

    return resampleMeans

def unscrambleChans(timeSeriesDat):
    chanToElec = [63, 64, 62, 61, 59, 58, 60, 54, 57, 50, 53, 49, 52, 45, 55, 44, 56, 39, 51, 43,
                  46, 38, 48, 37, 47, 36, 42, 35, 41, 34, 40, 33, 96, 90, 95, 89, 94, 88, 93, 87,
                  92, 82, 86, 81, 91, 77, 85, 83, 84, 78, 80, 73, 79, 74, 75, 76, 71, 72, 68, 69,
                  66, 70, 65, 67, 128, 120, 127, 119, 126, 118, 125, 117, 124, 116, 123, 115, 122, 114, 121, 113,
                  112, 111, 109, 110, 107, 108, 106, 105, 104, 103, 102, 101, 100, 99, 97, 98, 32, 30, 31, 29,
                  28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 16, 17, 7, 15, 6, 14, 5, 13, 4, 12, 3, 11, 2, 10, 1, 9, 8]
    chanToElec = np.array(chanToElec).astype(np.int32)-1
    
    unscrambledDat = timeSeriesDat.copy()
    for x in range(len(chanToElec)):
        unscrambledDat[:,chanToElec[x]] = timeSeriesDat[:,x]
        
    return unscrambledDat

def triggeredAvg(features, eventIdx, eventCodes, window, smoothSD=0, computeCI=True, nResamples=100):
    winLen = window[1]-window[0]
    codeList = np.unique(eventCodes)
    
    featAvg = np.zeros([len(codeList), winLen, features.shape[1]])
    featCI = np.zeros([len(codeList), winLen, features.shape[1], 2])
    allTrials = []
    
    for codeIdx in range(len(codeList)):
        print(codeIdx)
        trlIdx = np.squeeze(np.argwhere(eventCodes==codeList[codeIdx]))
        trlSnippets = []
        for t in trlIdx:
            trlSnippets.append(features[(eventIdx[t]+window[0]):(eventIdx[t]+window[1]),:])
        
        trlConcat = np.stack(trlSnippets,axis=0)
        allTrials.append(trlConcat)
            
        if smoothSD>0:
            trlConcat = gaussian_filter1d(trlConcat, smoothSD, axis=1)

        featAvg[codeIdx,:,:] = np.mean(trlConcat, axis=0)
        
        if computeCI:
            tmp = np.percentile(meanResamples(trlConcat, nResamples), [2.5, 97.5], axis=0)   
            featCI[codeIdx,:,:,:] = np.transpose(tmp,[1,2,0]) 
        
    return featAvg, featCI, allTrials

def plotSimilarityMatrix(cMat):
    plt.figure(figsize=(cMat.shape[0]*0.08,cMat.shape[0]*0.08),dpi=300)
    plt.imshow(cMat,clim=[-1, 1],cmap='bwr_r')
    plt.gca().invert_yaxis()
    plt.xticks(ticks=np.arange(0,cMat.shape[0]), labels=theseLabels, rotation=45, fontsize=6)
    plt.yticks(ticks=np.arange(0,cMat.shape[0]), labels=theseLabels, fontsize=6)
    plt.title(plotTitles[pIdx],fontsize=6)
    cbar = plt.colorbar()
    for t in cbar.ax.get_yticklabels():
        t.set_fontsize(6)
        
def loadTFRecord(files):

    dataset = tf.data.TFRecordDataset(files)
    maxSeqElements = 500
    nInputFeatures = 256

    datasetFeatures = {
        "inputFeatures": tf.io.FixedLenSequenceFeature([nInputFeatures], tf.float32, allow_missing=True),
        "newClassSignal": tf.io.FixedLenSequenceFeature([], tf.float32, allow_missing=True),
        "ceMask": tf.io.FixedLenSequenceFeature([], tf.float32, allow_missing=True),
        "seqClassIDs": tf.io.FixedLenFeature((maxSeqElements), tf.int64),
        "nTimeSteps": tf.io.FixedLenFeature((), tf.int64),
        "nSeqElements": tf.io.FixedLenFeature((), tf.int64),
        "transcription": tf.io.FixedLenFeature((maxSeqElements), tf.int64)
    }

    def parseDatasetFunction(exampleProto):
        return tf.io.parse_single_example(exampleProto, datasetFeatures)

    dataset = dataset.map(parseDatasetFunction)

    allDat = []
    trueSentences = []
    seqElements = []

    def _convert_to_ascii(text):
        return [ord(char) for char in text]

    for dat in dataset:
        allDat.append(dat['inputFeatures'].numpy())

        trans = dat['transcription'].numpy()
        trans = trans[trans!=0]
        sent = ''
        for t in trans:
            sent += chr(t)
        trueSentences.append(sent)
        
        seqElements.append(dat['seqClassIDs'].numpy())
        
    return allDat, trueSentences, seqElements

def plotPreamble():
    import matplotlib.pyplot as plt

    SMALL_SIZE=5
    MEDIUM_SIZE=6
    BIGGER_SIZE=7

    plt.rc('font', size=SMALL_SIZE)          # controls default text sizes
    plt.rc('axes', titlesize=MEDIUM_SIZE)     # fontsize of the axes title
    plt.rc('axes', labelsize=MEDIUM_SIZE)    # fontsize of the x and y labels
    plt.rc('xtick', labelsize=SMALL_SIZE)    # fontsize of the tick labels
    plt.rc('ytick', labelsize=SMALL_SIZE)    # fontsize of the tick labels
    plt.rc('legend', fontsize=SMALL_SIZE)    # legend fontsize
    plt.rc('figure', titlesize=BIGGER_SIZE)  # fontsize of the figure title
    plt.rcParams['svg.fonttype'] = 'none'
    
def werWithCI(allTrueSeq, allDecSeq):
    from neuralDecoder.utils.rnnEval import wer as wer

    editDist = np.zeros([len(allTrueSeq)])
    strLen = np.zeros([len(allTrueSeq)])
    for x in range(len(allTrueSeq)):
        editDist[x] = wer(allTrueSeq[x], allDecSeq[x])
        strLen[x] = len(allTrueSeq[x])

    meanWER = np.sum(editDist)/np.sum(strLen)

    nBoot = 10000
    bootWER = np.zeros([nBoot])
    for b in range(nBoot):
        shuffIdx = np.random.randint(len(editDist),size=len(editDist))
        bootWER[b] = np.sum(editDist[shuffIdx])/np.sum(strLen[shuffIdx])
    
    return meanWER, np.percentile(bootWER, [2.5, 97.5])

def werInference(lmDir, ckptDirs, datasets, layerIdx, useBlankPenalty=True, cartesianProduct=True, channelMask=[]):
    
    if useBlankPenalty:
        acousticScale = 0.8
    else:
        acousticScale = 1.2
        
    ngramDecoder = lmDecoderUtils.build_lm_decoder(
        lmDir,
        acoustic_scale=acousticScale, #1.2
        nbest=1,
        beam=17
    )
    
    def infer(ckptDir, layerIdx, dataset):
        args = OmegaConf.load(os.path.join(ckptDir, 'args.yaml'))
        args['loadDir'] = ckptDir
        args['mode'] = 'infer'
        args['loadCheckpointIdx'] = None

        for x in range(len(args['dataset']['datasetProbabilityVal'])):
            args['dataset']['datasetProbabilityVal'][x] = 0.0
        args['dataset']['datasetProbabilityVal'][layerIdx] = 1.0
        args['dataset']['sessions'][layerIdx] = dataset
        
        if channelMask!=[]:
            args['channelMask'] = channelMask
            
        # Initialize model
        tf.compat.v1.reset_default_graph()
        nsd = NeuralSequenceDecoder(args)

        # Inference
        out = nsd.inference()

        if useBlankPenalty:
            bp = np.log(2)
        else:
            bp = np.log(1)

        decoder_out = lmDecoderUtils.cer_with_lm_decoder(ngramDecoder, out, outputType='speech_sil', blankPenalty=bp)
        
        def _ascii_to_text(text):
            endIdx = np.argwhere(text==0)
            return ''.join([chr(char) for char in text[0:endIdx[0,0]]])

        trueTranscriptions = []
        for x in range(out['transcriptions'].shape[0]):
            trueTranscriptions.append(_ascii_to_text(out['transcriptions'][x,:]))

        return decoder_out['wer'], out['cer'], decoder_out['decoded_transcripts'], trueTranscriptions
    
    if cartesianProduct:
        rnn_wer = []
        rnn_per = []
        rnn_decTrans = []
        rnn_trueTrans = []
        for rnnIdx in range(len(ckptDirs)):    
            all_wer = []
            all_per = []
            all_decTrans = []
            all_trueTrans = []
            for sessIdx in range(len(datasets)):
                wer, per, decTrans, trueTrans = infer(ckptDirs[rnnIdx], layerIdx[sessIdx], datasets[sessIdx])
                all_wer.append(wer)
                all_per.append(per)
                all_decTrans.append(decTrans)
                all_trueTrans.append(trueTrans)
                
            rnn_wer.append(all_wer)
            rnn_per.append(all_per)
            rnn_decTrans.append(all_decTrans)
            rnn_trueTrans.append(all_trueTrans)
    else:
        rnn_wer = []
        rnn_per = []
        rnn_decTrans = []
        rnn_trueTrans = []
        for sessIdx in range(len(datasets)):
            wer, per, decTrans, trueTrans = infer(ckptDirs[sessIdx], layerIdx[sessIdx], datasets[sessIdx])
            rnn_wer.append(wer)
            rnn_per.append(per)                
            rnn_decTrans.append(decTrans)
            rnn_trueTrans.append(trueTrans)

    return rnn_wer, rnn_per, rnn_decTrans, rnn_trueTrans

def plotDotDistributions(dotData, plotLabels):
    import matplotlib.pyplot as plt
    from analysis import plotPreamble

    plotPreamble()

    plt.figure(figsize=(1.0,1.5),dpi=300)
    for x in range(len(plotLabels)):
        plt.plot(x+(np.random.uniform(size=[10])-0.5)*0.2, dotData[plotIdx]*100, 
                 'o', markersize=0.2, color='C0')
        plt.plot([x-0.2, x+0.2], [np.mean(dotData[plotIdx])*100, np.mean(dotData[plotIdx])*100], '-',  color='C0', linewidth=1)

    plt.gca().set_xticks(np.arange(0,len(plotLabels)))
    plt.gca().set_xticklabels(plotLabels, rotation=45)
    
def perInference(lmDir, ckptDirs, datasets, layerIdx, useBlankPenalty=True, cartesianProduct=True, channelMask=[]):
    
    def infer(ckptDir, layerIdx, dataset):
        args = OmegaConf.load(os.path.join(ckptDir, 'args.yaml'))
        args['loadDir'] = ckptDir
        args['mode'] = 'infer'
        args['loadCheckpointIdx'] = None

        for x in range(len(args['dataset']['datasetProbabilityVal'])):
            args['dataset']['datasetProbabilityVal'][x] = 0.0
        args['dataset']['datasetProbabilityVal'][layerIdx] = 1.0
        args['dataset']['sessions'][layerIdx] = dataset
        
        if channelMask!=[]:
            args['channelMask'] = list(channelMask)
            
        # Initialize model
        tf.compat.v1.reset_default_graph()
        nsd = NeuralSequenceDecoder(args)

        # Inference
        out = nsd.inference()

        if useBlankPenalty:
            bp = np.log(2)
        else:
            bp = np.log(1)

        return out['cer']
    
    if cartesianProduct:
        rnn_per = []
        for rnnIdx in range(len(ckptDirs)):    
            all_per = []
            for sessIdx in range(len(datasets)):
                per = infer(ckptDirs[rnnIdx], layerIdx[sessIdx], datasets[sessIdx])
                all_per.append(per)
                
            rnn_per.append(all_per)
    else:
        rnn_per = []
        for sessIdx in range(len(datasets)):
            per= infer(ckptDirs[sessIdx], layerIdx[sessIdx], datasets[sessIdx])
            rnn_per.append(per)                

    return rnn_per

def perInferenceDefault(lmDir, ckptDirs, datasets, layerIdx, useBlankPenalty=True, cartesianProduct=True, channelMask=[]):
    
    def infer(ckptDir, layerIdx, dataset):
        args = OmegaConf.load(os.path.join(ckptDir, 'args.yaml'))
        args['loadDir'] = ckptDir
        args['mode'] = 'infer'
        args['loadCheckpointIdx'] = None

        if channelMask!=[]:
            args['channelMask'] = list(channelMask)
            
        # Initialize model
        tf.compat.v1.reset_default_graph()
        nsd = NeuralSequenceDecoder(args)

        # Inference
        out = nsd.inference()

        if useBlankPenalty:
            bp = np.log(2)
        else:
            bp = np.log(1)

        return out['cer']
    
    if cartesianProduct:
        rnn_per = []
        for rnnIdx in range(len(ckptDirs)):    
            all_per = []
            for sessIdx in range(len(datasets)):
                per = infer(ckptDirs[rnnIdx], layerIdx[sessIdx], datasets[sessIdx])
                all_per.append(per)
                
            rnn_per.append(all_per)
    else:
        rnn_per = []
        for sessIdx in range(len(datasets)):
            per= infer(ckptDirs[sessIdx], layerIdx[sessIdx], datasets[sessIdx])
            rnn_per.append(per)                

    return rnn_per

from matplotlib.pyplot import cm 

def heatmapPlotCircles(tuning, isSig, clim, titles, layout):
    circle_cmap = cm.Blues(np.linspace(0,1,256))
    nPlots = tuning.shape[1]
    if layout=='6v':
        arrRows = [np.arange(64,128).astype(np.int32), np.arange(0,64).astype(np.int32)]
    elif layout=='ifg':
        arrRows = [np.flip(np.arange(64,128).astype(np.int32)), np.flip(np.arange(0,64).astype(np.int32))]
        
    plt.figure(figsize=(nPlots*0.8,2*0.8), dpi=300)
    for plotIdx in range(nPlots):
        for arrIdx in range(len(arrRows)):
            plt.subplot(2,nPlots,1+plotIdx+arrIdx*nPlots)
            
            matVals = tuning[arrRows[arrIdx], plotIdx]
            mat = np.reshape(matVals, [8,8], 'F')
            
            matVals_sig = isSig[arrRows[arrIdx], plotIdx]
            mat_sig = np.reshape(matVals_sig, [8,8], 'F')
            
            for x in range(8):
                for y in range(8):
                    if mat_sig[y,x]:
                        thisColor = np.round(255*mat[y,x]/clim[1]).astype(np.int32)
                        if thisColor>255:
                            thisColor = 255
                        if thisColor<0:
                            thisColor = 0
                            
                        plt.plot(x,-y,'o',color=circle_cmap[thisColor,:],markersize=4,markeredgecolor ='k',markeredgewidth=0.1)
                    else:
                        plt.plot(x,-y,'x',color='k',markersize=1,alpha=0.1)
            
            plt.gca().set_xticks([])
            plt.gca().set_yticks([])
            
            ax = plt.gca()
            for axis in ['top','bottom','left','right']:
                ax.spines[axis].set_linewidth(0.75)
            
            if arrIdx==0:
                plt.title(titles[plotIdx],fontsize=6)
                
import matplotlib.pyplot as plt
def heatmapPlot(tuning, clim, titles, layout):
    nPlots = tuning.shape[1]
    if layout=='6v':
        arrRows = [np.arange(64,128).astype(np.int32), np.arange(0,64).astype(np.int32)]
    elif layout=='ifg':
        arrRows = [np.flip(np.arange(64,128).astype(np.int32)), np.flip(np.arange(0,64).astype(np.int32))]
        
    plt.figure(figsize=(nPlots,2), dpi=300)
    for plotIdx in range(nPlots):
        for arrIdx in range(len(arrRows)):
            plt.subplot(2,nPlots,1+plotIdx+arrIdx*nPlots)
            
            matVals = tuning[arrRows[arrIdx], plotIdx]
            mat = np.reshape(matVals, [8,8], 'F')
            
            plt.imshow(mat, aspect='auto', clim=clim, cmap='RdBu')
            plt.gca().set_xticks([])
            plt.gca().set_yticks([])
            if arrIdx==0:
                plt.title(titles[plotIdx],fontsize=6)
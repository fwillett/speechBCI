import numpy as np
import scipy.stats
from scipy.ndimage import gaussian_filter1d
from numba import njit
import matplotlib.pyplot as plt
from matplotlib import cm
import numpy as np
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
        trlIdx = np.squeeze(np.argwhere(eventCodes==codeList[codeIdx]))
        trlSnippets = []
        for t in trlIdx:
            if (eventIdx[t]+window[0])<0 or (eventIdx[t]+window[1])>=features.shape[0]:
                continue
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

def makeTuningHeatmap(dat, sets, window):

    features = dat['tx2'].astype(np.float32)
    nFeat = features.shape[1]
    nTrials = dat['goTrialEpochs'].shape[0]
    nClasses = dat['cueList'].shape[1]
    
    trialVectors = np.zeros([nTrials, features.shape[1]])
    predVectors = np.zeros([nTrials, features.shape[1]])
    
    tuningR2 = np.zeros([nFeat, len(sets)])
    tuningPVal = np.zeros([nFeat, len(sets)])
    
    for t in range(nTrials):
        trialVectors[t,:] = np.mean(features[(dat['goTrialEpochs'][t,0]+window[0]):(dat['goTrialEpochs'][t,0]+window[1])], axis=0)
        
    #split observations into folds
    nFolds = 5
    heldOutIdx = []
    minPerFold = np.floor(trialVectors.shape[0]/nFolds).astype(np.int32)
    remainder = trialVectors.shape[0]-minPerFold*nFolds
    if remainder>0:
        currIdx = np.arange(0,(minPerFold+1)).astype(np.int32)
    else:
        currIdx = np.arange(0,minPerFold).astype(np.int32)

    for x in range(nFolds):
        heldOutIdx.append(currIdx.copy())
        currIdx += len(currIdx)
        if remainder!=0 and x==remainder:
            currIdx = currIdx[0:-1]

    for foldIdx in range(nFolds):
        meanVectors = np.zeros([nClasses, nFeat])
        for m in range(nClasses):
            trlIdx = np.squeeze(np.argwhere(np.squeeze(dat['trialCues']-1)==m))
            trlIdx = np.setdiff1d(trlIdx, heldOutIdx[foldIdx])
            meanVectors[m,:] = np.mean(trialVectors[trlIdx,:], axis=0)
            
        for t in heldOutIdx[foldIdx]:
            predVectors[t,:] = meanVectors[dat['trialCues'][t,0]-1,:]
  
    for setIdx in range(len(sets)):
        mSet = sets[setIdx]
        trlIdx = np.argwhere(np.in1d(np.squeeze(dat['trialCues']-1), mSet))
        SSTOT = np.sum(np.square(trialVectors[trlIdx,:]-np.mean(trialVectors[trlIdx,:],axis=0,keepdims=True)), axis=0)
        SSERR = np.sum(np.square(trialVectors[trlIdx,:]-predVectors[trlIdx,:]), axis=0)
        
        tuningR2[:,setIdx] = 1-SSERR/SSTOT
        
        groupVectors = []
        for m in mSet:
            trlIdx = np.argwhere(np.squeeze(dat['trialCues']-1)==m)
            groupVectors.append(trialVectors[trlIdx,:])
            
        fResults = scipy.stats.f_oneway(*groupVectors,axis=0)
        tuningPVal[:,setIdx] = fResults[1]

    return tuningR2, tuningPVal

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
                
#gaussian naive bayes classifier with variable time window and channel set
def gnb_loo(trials_input, timeWindow, chanIdx):
    unroll_Feat = []
    for t in range(len(trials_input)):
        for x in range(trials_input[t].shape[0]):
            unroll_Feat.append(trials_input[t][x,:,:])

    unroll_Feat = np.concatenate(unroll_Feat, axis=0)
    mn = np.mean(unroll_Feat, axis=0)
    sd = np.std(unroll_Feat, axis=0)
    
    unroll_X = []
    unroll_y = []

    for t in range(len(trials_input)):
        for x in range(trials_input[t].shape[0]):
            tmp = (trials_input[t][x,:,:] - mn[np.newaxis,:])/sd[np.newaxis,:]
            b1 = np.mean(tmp[timeWindow[0]:timeWindow[1],chanIdx], axis=0)
            
            unroll_X.append(np.concatenate([b1]))
            unroll_y.append(t)

    unroll_X = np.stack(unroll_X, axis=0)
    unroll_y = np.array(unroll_y).astype(np.int32)
    
    from sklearn.naive_bayes import GaussianNB

    y_pred = np.zeros([unroll_X.shape[0]])
    for t in range(unroll_X.shape[0]):
        X_train = np.concatenate([unroll_X[0:t,:], unroll_X[(t+1):,:]], axis=0)
        y_train = np.concatenate([unroll_y[0:t], unroll_y[(t+1):]])

        gnb = GaussianNB()
        gnb.fit(X_train, y_train)
        gnb.var_ = np.ones(gnb.var_.shape)*np.mean(gnb.var_)

        pred_val = gnb.predict(unroll_X[np.newaxis,t,:])
        y_pred[t] = pred_val
        
    return y_pred, unroll_y

def bootCI(x,y):
    nReps = 10000
    bootAcc = np.zeros([nReps])
    for n in range(nReps):
        shuffIdx = np.random.randint(len(x),size=len(x))
        bootAcc[n] = np.mean(x[shuffIdx]==y[shuffIdx])
        
    return np.percentile(bootAcc,[2.5, 97.5])
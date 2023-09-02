""" Author: Benyamin Meschede-Krasa 
cross validated confidence intervals for cv metrics """
import os
import numpy as np
from scipy.stats import norm
import pandas as pd
import matplotlib.pyplot as plt

######################
######  PARAMS  ######
######################

##################################################
######                  MAIN                ######
##################################################

def cvJackknifeCI(fullDataStatistic, dataFun, dataTrials, alpha):
    """compute confidence intervals for cv statistic
    Parameters
    ----------
    fullDataStatistic : list
        list of statistics computed from `dataTrials` 
    dataFun : func
        callable function that transforms `dataTrials` to the
        statistic
    dataTrials : array (n_classes, n_trials, n_features)
        list of data from classes used to compute `fullDataStatistic`
    alpha : float
        alpha for confidence interval coverage (e.g. 0.05 for 95%CI)
    Returns
    -------
    CI : array (n_statistics, 2)
        upper and lower bounds for each statistic
    jacks : array (n_folds, n_statistics)
        folds from jackknifing (loo)
    """

    # NOTE: implementation only supports data cells with same numbers of trials unlike original implementation
    nFolds = dataTrials[0].shape[0] # Leave one trial out cross validation
    folds = np.arange(nFolds)
    jacks = np.zeros([nFolds, len(fullDataStatistic)]) 
    for foldIdx in folds:
        deleteTrials = [list(dataTrial) for dataTrial in dataTrials]
        for x in range(len(deleteTrials)):
            deleteTrials[x].pop(foldIdx)
        jacks[foldIdx,:] = dataFun(*deleteTrials)[:2]

    ps = nFolds*np.array(fullDataStatistic) - (nFolds-1)*jacks
    v = np.var(ps,axis=0) 
    
    multiplier = norm.ppf((1-alpha/2), 0, 1)
    CI = np.array([(fullDataStatistic - multiplier*np.sqrt(v/nFolds)), (fullDataStatistic + multiplier*np.sqrt(v/nFolds))])
    return CI, jacks

""" Author: Benyamin Meschede-Krasa 
cross validated distance, based on https://github.com/fwillett/cvVectorStats/blob/master/cvDistance.m """
import numpy as np

def cvDistance(class0,class1,subtractMean=False, CIMode='none',CIAlpha=0.05): #TODO implement CI
    """Estimate the distance between two distributions
    Parameters
    ----------
    class0 : ndarray (nTrials,nFeatures)
        samples from distributions to be compared 
    class1 : _type_
        _description_
    subtractMean : bool, optional
        If subtractMean is true, this will center each vector
        before computing the size of the difference, by default False
    CIMode : str
        method for computing confidence intervals. Currently only 'jackknife'
        is implmented
    CIAlpha : float
        alpha for confidence interval. Default is 0.05 which give the 95%
        confidence interval
    Returns
    -------
    squaredDistance : float
        cross-validated estimate of squared distance between class 1 and 2
    euclideanDistance : float
        cross-validated estimate of euclidean distance between class 1 and 2
    CI : ndarray(2,2)
        confidence intervals for squaredDistance (col 0) and euclideanDistance
        (col 1)
    """
    class0 = np.array(class0)
    class1 = np.array(class1)

    assert class0.shape == class1.shape, "Classes must have same shape, different numebrs of trials not implemented yet" #TODO implement different trial numebr for classes

    nTrials, nFeatures = class0.shape
    squaredDistanceEstimates=np.zeros([nTrials,1])

    for x in range(nTrials):
        bigSetIdx = list(range(nTrials))
        smallSetIndex = bigSetIdx.pop(x)

        meanDiff_bigSet = np.mean(class0[bigSetIdx,:] - class1[bigSetIdx,:],axis=0)
        meanDiff_smallSet = class0[smallSetIndex,:] - class1[smallSetIndex,:]
        if subtractMean:
            squaredDistanceEstimates[x] = np.dot(meanDiff_bigSet-np.mean(meanDiff_bigSet),(meanDiff_smallSet-np.mean(meanDiff_smallSet)).transpose())
        else:
            squaredDistanceEstimates[x] = np.dot(meanDiff_bigSet,meanDiff_smallSet.transpose())
    
    squaredDistance = np.mean(squaredDistanceEstimates)
    euclideanDistance = np.sign(squaredDistance)*np.sqrt(np.abs(squaredDistance))
    
    if CIMode == 'jackknife':
        wrapperFun = lambda x,y : cvDistance(x,y,subtractMean=subtractMean)
        [CI, CIDistribution] = cvJackknifeCI([squaredDistance, euclideanDistance], wrapperFun, [class0, class1], CIAlpha)
    elif CIMode == 'none':
        CI = []
        CIDistribution = []
    else:
        raise ValueError(f"CIMode {CIMode} not implemented or is invalid. select from ['jackknife','none']")

    return squaredDistance, euclideanDistance, CI, CIDistribution 

""" Author: Benyamin Meschede-Krasa 
cross validated distance, based on https://github.com/fwillett/cvVectorStats/blob/master/cvDistance.m """
import numpy as np

def cvCorr(class0,class1,subtractMean=False, CIMode='none',CIAlpha=0.05): #TODO implement CI
    """Estimate the distance between two distributions
    Parameters
    ----------
    class0 : ndarray (nTrials,nFeatures)
        samples from distributions to be compared 
    class1 : _type_
        _description_
    subtractMean : bool, optional
        If subtractMean is true, this will center each vector
        before computing the size of the difference, by default False
    CIMode : str
        method for computing confidence intervals. Currently only 'jackknife'
        is implmented
    CIAlpha : float
        alpha for confidence interval. Default is 0.05 which give the 95%
        confidence interval
    Returns
    -------
    squaredDistance : float
        cross-validated estimate of squared distance between class 1 and 2
    euclideanDistance : float
        cross-validated estimate of euclidean distance between class 1 and 2
    CI : ndarray(2,2)
        confidence intervals for squaredDistance (col 0) and euclideanDistance
        (col 1)
    """
    class0 = np.array(class0)
    class1 = np.array(class1)

    assert class0.shape == class1.shape, "Classes must have same shape, different numebrs of trials not implemented yet" #TODO implement different trial numebr for classes
    
    unbiasedMag1 = cvDistance(class0, np.zeros(class0.shape), subtractMean=True)
    unbiasedMag2 = cvDistance(class1, np.zeros(class1.shape), subtractMean=True)
    
    unbiasedMag1 = unbiasedMag1[1]
    unbiasedMag2 = unbiasedMag2[1]
    
    mn1 = np.mean(class0, axis=0)
    mn2 = np.mean(class1, axis=0)
    cvCorrEst = np.dot((mn1-np.mean(mn1)),(mn2-np.mean(mn2)))/(unbiasedMag1*unbiasedMag2)
    
    return cvCorrEst

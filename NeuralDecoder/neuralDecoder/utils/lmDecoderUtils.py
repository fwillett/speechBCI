import os
from time import time

import numpy as np
from tqdm.notebook import trange, tqdm
import tensorflow as tf

import lm_decoder
import neuralDecoder.utils.rnnEval as rnnEval

'''
Neural Language Model Utils
'''
def build_gpt2(modelName='gpt2-xl', cacheDir=None):
    from transformers import GPT2TokenizerFast, TFGPT2LMHeadModel
    tokenizer = GPT2TokenizerFast.from_pretrained(modelName, cache_dir=cacheDir)
    model = TFGPT2LMHeadModel.from_pretrained(modelName, cache_dir=cacheDir)

    tokenizer.padding_side = "right"
    tokenizer.pad_token = tokenizer.eos_token

    return model, tokenizer


def build_opt(modelName='facebook/opt-6.7b', cacheDir=None, device='auto', load_in_8bit=False):
    from transformers import AutoModelForCausalLM, AutoTokenizer

    tokenizer = AutoTokenizer.from_pretrained(modelName, cache_dir=cacheDir)
    model = AutoModelForCausalLM.from_pretrained(modelName, cache_dir=cacheDir,
                                                 device_map=device, load_in_8bit=load_in_8bit)

    tokenizer.padding_side = "right"
    tokenizer.pad_token = tokenizer.eos_token

    return model, tokenizer

def rescore_with_gpt2(model, tokenizer, hypotheses, lengthPenalty):
    model_class = type(model).__name__
    if model_class.startswith('TF'):
        inputs = tokenizer(hypotheses, return_tensors='tf', padding=True)
        outputs = model(inputs)
        logProbs = tf.math.log(tf.nn.softmax(outputs['logits'], -1))
        logProbs = logProbs.numpy()
    else:
        import torch
        inputs = tokenizer(hypotheses, return_tensors='pt', padding=True)
        with torch.no_grad():
            outputs = model(**inputs)
            logProbs = torch.nn.functional.log_softmax(outputs['logits'].float(), -1).numpy()

    newLMScores = []
    B, T, _ = logProbs.shape
    for i in range(B):
        n_tokens = np.sum(inputs['attention_mask'][i].numpy())

        newLMScore = 0.
        for j in range(1, n_tokens):
            newLMScore += logProbs[i, j - 1, inputs['input_ids'][i, j].numpy()]

        newLMScores.append(newLMScore - n_tokens * lengthPenalty)

    return newLMScores

def gpt2_lm_decode(model, tokenizer, nbest, acousticScale, lengthPenlaty, alpha,
                   returnConfidence=False):
    hypotheses = []
    acousticScores = []
    oldLMScores = []
    for out in nbest:
        hyp = out[0].strip()
        if len(hyp) == 0:
            continue
        hyp = hyp.replace('>', '')
        hyp = hyp.replace('  ', ' ')
        hyp = hyp.replace(' ,', ',')
        hyp = hyp.replace(' .', '.')
        hyp = hyp.replace(' ?', '?')
        hypotheses.append(hyp)
        acousticScores.append(out[1])
        oldLMScores.append(out[2])

    if len(hypotheses) == 0:
        return "" if not returnConfidence else ("", 0.)

    acousticScores = np.array(acousticScores)
    newLMScores = np.array(rescore_with_gpt2(model, tokenizer, hypotheses, lengthPenlaty))
    oldLMScores = np.array(oldLMScores)

    totalScores = alpha * newLMScores + (1 - alpha) * oldLMScores + acousticScale * acousticScores
    maxIdx = np.argmax(totalScores)
    bestHyp = hypotheses[maxIdx]
    if not returnConfidence:
        return bestHyp
    else:
        totalScores = totalScores - np.max(totalScores)
        probs = np.exp(totalScores)
        return bestHyp, probs[maxIdx] / np.sum(probs)

def cer_with_gpt2_decoder(model, tokenizer, nbestOutputs, acousticScale,
                          inferenceOut, outputType='handwriting',
                          returnCI=False,
                          lengthPenalty=0.0,
                          alpha=1.0):
    decodedSentences = []
    confidences = []
    for i in trange(len(nbestOutputs)):
        decoded, confidence = gpt2_lm_decode(model, tokenizer, nbestOutputs[i], acousticScale, lengthPenalty, alpha, returnConfidence=True)
        decodedSentences.append(decoded)
        confidences.append(confidence)

    if outputType == 'handwriting':
        trueSentences = _extract_true_sentences(inferenceOut)
    elif outputType == 'speech' or outputType == 'speech_sil':
        trueSentences = _extract_transcriptions(inferenceOut)
    trueSentencesProcessed = []
    for trueSent in trueSentences:
        if outputType == 'handwriting':
            trueSent = trueSent.replace('>',' ')
            trueSent = trueSent.replace('~','.')
            trueSent = trueSent.replace('#','')
        if outputType == 'speech' or outputType == 'speech_sil':
            trueSent = trueSent.strip()
        trueSentencesProcessed.append(trueSent)

    cer, wer = _cer_and_wer(decodedSentences, trueSentencesProcessed, outputType, returnCI)

    return {
        'cer': cer,
        'wer': wer,
        'decoded_transcripts': decodedSentences,
        'confidences': confidences
    }

'''
NGram Language Model Utils
'''
def build_lm_decoder(model_path,
                     max_active=7000,
                     min_active=200,
                     beam=17.,
                     lattice_beam=8.,
                     acoustic_scale=1.5,
                     ctc_blank_skip_threshold=1.0,
                     length_penalty=0.0,
                     nbest=1):
    decode_opts = lm_decoder.DecodeOptions(
        max_active,
        min_active,
        beam,
        lattice_beam,
        acoustic_scale,
        ctc_blank_skip_threshold,
        length_penalty,
        nbest
    )

    TLG_path = os.path.join(model_path, 'TLG.fst')
    words_path = os.path.join(model_path, 'words.txt')
    G_path = os.path.join(model_path, 'G.fst')
    rescore_G_path = os.path.join(model_path, 'G_no_prune.fst')
    if not os.path.exists(rescore_G_path):
        rescore_G_path = ""
        G_path = ""
    if not os.path.exists(TLG_path):
        raise ValueError('TLG file not found at {}'.format(TLG_path))
    if not os.path.exists(words_path):
        raise ValueError('words file not found at {}'.format(words_path))

    decode_resource = lm_decoder.DecodeResource(
        TLG_path,
        G_path,
        rescore_G_path,
        words_path,
        ""
    )
    decoder = lm_decoder.BrainSpeechDecoder(decode_resource, decode_opts)

    return decoder

def lm_decode(decoder, logits, returnNBest=False, rescore=False,
              blankPenalty=0.0,
              logPriors=None):
    assert len(logits.shape) == 2

    if logPriors is None:
        logPriors = np.zeros([1, logits.shape[1]])
    lm_decoder.DecodeNumpy(decoder, logits, logPriors, blankPenalty)
    decoder.FinishDecoding()
    if rescore:
        decoder.Rescore()


    if not returnNBest:
        if len(decoder.result()) == 0:
            decoded = ''
        else:
            decoded = decoder.result()[0].sentence
    else:
        decoded = []
        for r in decoder.result():
            decoded.append((r.sentence, r.ac_score, r.lm_score))

    decoder.Reset()

    return decoded

def nbest_with_lm_decoder(decoder,
                          inferenceOut,
                          includeSpaceSymbol=True,
                          outputType='handwriting',
                          rescore=False,
                          blankPenalty=0.0):
    logits = inferenceOut['logits']
    logitLengths = inferenceOut['logitLengths']
    if outputType == 'handwriting':
        logits = rearrange_handwriting_logits(logits, includeSpaceSymbol)
    elif outputType == 'speech' or outputType == 'speech_sil':
        logits = rearrange_speech_logits(logits, has_sil=(outputType == 'speech_sil'))

    nbestOutputs = []
    for i in range(len(logits)):
        nbest = lm_decode(decoder,
                          logits[i, :logitLengths[i]],
                          returnNBest=True,
                          blankPenalty=blankPenalty,
                          rescore=rescore)
        nbestOutputs.append(nbest)

    return nbestOutputs

def cer_with_lm_decoder(decoder, inferenceOut, includeSpaceSymbol=True,
                        outputType='handwriting',
                        returnCI=False,
                        rescore=False,
                        blankPenalty=0.0,
                        logPriors=None):
    # Reshape logits to kaldi order
    logits = inferenceOut['logits']
    if outputType == 'handwriting':
        logits = rearrange_handwriting_logits(logits, includeSpaceSymbol)
        trueSentences = _extract_true_sentences(inferenceOut)
    elif outputType == 'speech' or outputType == 'speech_sil':
        logits = rearrange_speech_logits(logits, has_sil=('speech_sil' == outputType))
        trueSentences = _extract_transcriptions(inferenceOut)

    # Decode with language model
    decodedSentences = []
    decodeTime = []
    for l in trange(len(inferenceOut['logits'])):
        decoder.Reset()

        logitLen = inferenceOut['logitLengths'][l]
        start = time()
        decoded = lm_decode(decoder,
                            logits[l, :logitLen],
                            rescore=rescore,
                            blankPenalty=blankPenalty,
                            logPriors=logPriors)

        # Post-process
        if outputType == 'handwriting':
            if includeSpaceSymbol:
                decoded = decoded.replace(' ', '')
            else:
                decoded = decoded.replace(' ', '>')
            decoded = decoded.replace('.', '~')
        elif outputType == 'speech' or outputType == 'speech_sil':
            decoded = decoded.strip()

        decodeTime.append((time() - start) * 1000)
        decodedSentences.append(decoded)

    assert len(trueSentences) == len(decodedSentences)

    cer, wer = _cer_and_wer(decodedSentences, trueSentences, outputType, returnCI)

    return {
        'cer': cer,
        'wer': wer,
        'decoded_transcripts': decodedSentences,
        'true_transcripts': trueSentences,
        'decode_time': decodeTime
    }

def rearrange_handwriting_logits(logits, includeSpaceSymbol=True):
    char_range = list(range(0, 26))
    if includeSpaceSymbol:
        symbol_range = [26, 27, 30, 29, 28]
    else:
        symbol_range = [27, 30, 29, 28]
    logits = logits[:, :, [31] + symbol_range + char_range]
    return logits

def rearrange_speech_logits(logits, has_sil=False):
    if not has_sil:
        logits = np.concatenate([logits[:, :, -1:], logits[:, :, :-1]], axis=-1)
    else:
        logits = np.concatenate([logits[:, :, -1:], logits[:, :, -2:-1], logits[:, :, :-2]], axis=-1)
    return logits

def _cer_and_wer(decodedSentences, trueSentences, outputType='handwriting',
                 returnCI=False):
    allCharErr = []
    allChar = []
    allWordErr = []
    allWord = []
    for x in range(len(decodedSentences)):
        decSent = decodedSentences[x]
        trueSent = trueSentences[x]

        nCharErr = rnnEval.wer([c for c in trueSent], [c for c in decSent])
        if outputType == 'handwriting':
            trueWords = trueSent.replace(">", " > ").split(" ")
            decWords = decSent.replace(">", " > ").split(" ")
        elif outputType == 'speech' or outputType == 'speech_sil':
            trueWords = trueSent.split(" ")
            decWords = decSent.split(" ")
        nWordErr = rnnEval.wer(trueWords, decWords)

        allCharErr.append(nCharErr)
        allWordErr.append(nWordErr)
        allChar.append(len(trueSent))
        allWord.append(len(trueWords))

    cer = np.sum(allCharErr) / np.sum(allChar)
    wer = np.sum(allWordErr) / np.sum(allWord)

    if not returnCI:
        return cer, wer
    else:
        allChar = np.array(allChar)
        allCharErr = np.array(allCharErr)
        allWord = np.array(allWord)
        allWordErr = np.array(allWordErr)

        nResamples = 10000
        resampledCER = np.zeros([nResamples,])
        resampledWER = np.zeros([nResamples,])
        for n in range(nResamples):
            resampleIdx = np.random.randint(0, allChar.shape[0], [allChar.shape[0]])
            resampledCER[n] = np.sum(allCharErr[resampleIdx]) / np.sum(allChar[resampleIdx])
            resampledWER[n] = np.sum(allWordErr[resampleIdx]) / np.sum(allWord[resampleIdx])
        cerCI = np.percentile(resampledCER, [2.5, 97.5])
        werCI = np.percentile(resampledWER, [2.5, 97.5])

        return (cer, cerCI[0], cerCI[1]), (wer, werCI[0], werCI[1])

def _extract_transcriptions(inferenceOut):
    transcriptions = []
    for i in range(len(inferenceOut['transcriptions'])):
        endIdx = np.argwhere(inferenceOut['transcriptions'][i] == 0)[0, 0]
        trans = ''
        for c in range(endIdx):
            trans += chr(inferenceOut['transcriptions'][i][c])
        transcriptions.append(trans)

    return transcriptions

def _extract_true_sentences(inferenceOut):
    charMarks = ['a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z',
                 '>',',',"'",'~','?']

    trueSentences = []
    for i in range(len(inferenceOut['trueSeqs'])):
        trueSent = ''
        endIdx = np.argwhere(inferenceOut['trueSeqs'][i] == -1)
        endIdx = endIdx[0,0]
        for c in range(endIdx):
            trueSent += charMarks[inferenceOut['trueSeqs'][i][c]]
        trueSentences.append(trueSent)

    return trueSentences
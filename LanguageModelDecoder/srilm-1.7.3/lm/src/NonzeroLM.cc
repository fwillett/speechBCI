/*
 * NonzeroLM.cc --
 *	Wrapper language model to ensure nonzero probabilities.
 *
 */

#ifndef lint
static char Copyright[] = "Copyright (c) 2011 SRI International, 2017 Andreas Stolcke, Microsoft Corp.  All Rights Reserved.";
static char RcsId[] = "@(#)$Header: /home/srilm/CVS/srilm/lm/src/NonzeroLM.cc,v 1.5 2019/09/09 23:13:13 stolcke Exp $";
#endif

#include <stdlib.h>

#include "NonzeroLM.h"

const LogP LogP_PseudoZero = -99.0;	/* non-inf value used for log 0 */

NonzeroLM::NonzeroLM(Vocab &vocab, LM &lm, VocabString zerowordString, LogP unkProb)
    : LM(vocab), lm(lm), unkProb(unkProb)
{
    if (zerowordString && zerowordString[0]) {
	zeroword = vocab.addWord(zerowordString);
    } else {
	/*
	 * Disable zeroword mapping
	 */
	zeroword = Vocab_None;
    }
}

LogP
NonzeroLM::wordProb(VocabIndex word, const VocabIndex *context)
{
    LogP prob = lm.wordProb(word, context);

    /*
     * Override <unk> probability if desired
     */
    if (word == vocab.unkIndex() && unkProb != LogP_Zero) {
	if (unkProb == LogP_PseudoZero) {
	   return LogP_Zero;
	} else {
	   return unkProb;
	}
    }

    /*
     * Handle zero probs
     */
    if (prob == LogP_Zero && zeroword != Vocab_None && word != zeroword) {
	if (zeroword == vocab.unkIndex() && unkProb != LogP_Zero) {
	    prob = unkProb;
	} else {
	    prob = lm.wordProb(zeroword, context);
	}
    }

    return prob;
}

void *
NonzeroLM::contextID(VocabIndex word, const VocabIndex *context,
							unsigned &length)
{
    if (word == Vocab_None) {
	return lm.contextID(word, context, length);
    } else {
	LogP prob = lm.wordProb(word, context);

	if (prob == LogP_Zero && zeroword != Vocab_None && word != zeroword) {
	    return lm.contextID(zeroword, context, length);
	} else {
	    return lm.contextID(word, context, length);
	}
    }
}

LogP
NonzeroLM::contextBOW(const VocabIndex *context, unsigned length)
{
    return lm.contextBOW(context, length);
}

Boolean
NonzeroLM::isNonWord(VocabIndex word)
{
    return lm.isNonWord(word);
}

void
NonzeroLM::setState(const char *state)
{
    /*
     * Global state changes are propagated to the underlying model
     */
    lm.setState(state);
}

Boolean
NonzeroLM::addUnkWords()
{
    return lm.addUnkWords();
}


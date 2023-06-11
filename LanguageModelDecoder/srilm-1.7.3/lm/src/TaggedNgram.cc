/*
 * TaggedNgram.cc --
 *	Tagged N-gram backoff language models
 *
 */

#ifndef lint
static char Copyright[] = "Copyright (c) 1995-2010 SRI International.  All Rights Reserved.";
static char RcsId[] = "@(#)$Header: /home/srilm/CVS/srilm/lm/src/TaggedNgram.cc,v 1.8 2017/06/10 21:08:00 stolcke Exp $";
#endif

#include "TaggedNgram.h"

#include "Array.cc"

/*
 * Debug levels used
 */
#define DEBUG_NGRAM_HITS 2		/* from Ngram.cc */

TaggedNgram::TaggedNgram(TaggedVocab &vocab, unsigned neworder)
    : Ngram(vocab, neworder), vocab(vocab)
{
}

/*
 * The tagged ngram LM uses the following backoff hierarchy:
 * 
 *	- try word n-gram
 *	- try n-grams obtained by replacing the most distant word with its tag
 *	- try (n-1)-grams (recursively)
 */
LogP
TaggedNgram::wordProbBO(VocabIndex word, const VocabIndex *context, unsigned int clen)
{
    LogP result;
    VocabIndex usedContext[maxNgramOrder];
    VocabIndex untaggedWord = vocab.unTag(word);

    /*
     * Extract the word ngram from the context
     */
    unsigned i;
    for (i = 0; i < clen; i++) {
	usedContext[i] = vocab.unTag(context[i]);
    }
    usedContext[i] = Vocab_None;

    LogP *prob = findProb(untaggedWord, usedContext);

    if (prob) {
	if (running() && debug(DEBUG_NGRAM_HITS)) {
	    dout() << "[" << (clen + 1) << "gram]";
	}
	result = *prob;
    } else if (clen > 0) {
	/*
	 * Backoff weight from word to tag-ngram
	 */
	LogP *bow = findBOW(usedContext);
        LogP totalBOW = bow ? *bow : 0.0;

	/*
	 * Now replace the last word with its tag
	 */
	usedContext[clen - 1] = vocab.tagWord(Tagged_None,
				    vocab.getTag(context[clen - 1]));

	prob = findProb(untaggedWord, usedContext);

	if (prob) {
	    if (running() && debug(DEBUG_NGRAM_HITS)) {
		dout() << "[" << clen << "+Tgram]";
	    }
	    result = totalBOW + *prob;
	} else {
	    /*
	     * No tag-ngram, so back off to shorter context.
	     */
	    bow = findBOW(usedContext);

	    totalBOW += bow ? *bow : 0.0;
	    result = totalBOW + wordProbBO(word, context, clen - 1);
	}
    } else {
	result = LogP_Zero;
    }

    return result;
}


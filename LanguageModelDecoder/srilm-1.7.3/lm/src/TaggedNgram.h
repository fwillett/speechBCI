/*
 * TaggedNgram.h --
 *	Tagged N-gram backoff language models
 *
 * Copyright (c) 1995, SRI International.  All Rights Reserved.
 *
 * @(#)$Header: /home/srilm/CVS/srilm/lm/src/TaggedNgram.h,v 1.2 2017/06/10 21:08:00 stolcke Exp $
 *
 */

#ifndef _TaggedNgram_h_
#define _TaggedNgram_h_

#include "Ngram.h"
#include "TaggedVocab.h"

class TaggedNgram: public Ngram
{
public:
    TaggedNgram(TaggedVocab &vocab, unsigned int order);

    TaggedVocab &vocab;			/* vocabulary */

protected:
    virtual LogP wordProbBO(VocabIndex word, const VocabIndex *context,
							unsigned int clen);
};

#endif /* _TaggedNgram_h_ */

/*
 * LMStats.h --
 *	Generic LM statistics interface
 *
 * Copyright (c) 1995-2009 SRI International, 2008-2011 Andreas Stolcke, Microsoft Corp.  All Rights Reserved.
 *
 * @(#)$Header: /home/srilm/CVS/srilm/lm/src/LMStats.h,v 1.13 2019/09/09 23:13:13 stolcke Exp $
 *
 */

#ifndef _LMStats_h_
#define _LMStats_h_

#include <stdio.h>

#include "Boolean.h"
#include "Vocab.h"
#include "TextStats.h"
#include "Debug.h"

class LMStats: public Debug
{
public:
    LMStats(Vocab &vocab);
    virtual ~LMStats();

    virtual unsigned int countSentence(const VocabString *words) = 0;
    virtual unsigned int countSentence(const VocabString *words,
							const char *weight) = 0;
    virtual unsigned int countSentence(const VocabIndex *words) = 0;

    virtual unsigned int countString(char *sentence, unsigned weighted = 0);
    virtual unsigned int countFile(File &file, unsigned weighted = 0);

    virtual Boolean read(File &file) = 0;
    virtual void write(File &file) = 0;

    virtual void memStats(MemStats &stats) = 0;
    static void freeThread();
					/* compute memory stats */
    Vocab &vocab;			/* vocabulary */
    Boolean openVocab;			/* whether to add words as needed */

    Boolean addSentStart;		/* add <s> tags in counting */
    Boolean addSentEnd;			/* add </s> tags in counting */

    TextStats stats;			/* training data stats */
};

#endif /* _LMStats_h_ */


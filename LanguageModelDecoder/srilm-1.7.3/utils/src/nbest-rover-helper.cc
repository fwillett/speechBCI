/*
 * nbest-rover-helper --
 *	Preprocess nbest lists for nbest-rover
 */

#ifndef lint
static char Copyright[] = "Copyright (c) 1995-2010 SRI International, 2017 Andreas Stolcke, Microsoft Corp.  All Rights Reserved.";
static char RcsId[] = "@(#)$Id: nbest-rover-helper.cc,v 1.10 2019/09/09 23:13:15 stolcke Exp $";
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <locale.h>
#include <assert.h>
#include <math.h>
#ifndef _MSC_VER
# include <unistd.h>
#endif

#include "option.h"
#include "version.h"
#include "File.h"

#include "Prob.h"
#include "Vocab.h"
#include "NBest.h"
#include "RefList.h"
#include "VocabMultiMap.h"
#include "MultiwordVocab.h"	// for MultiwordSeparator
#include "Array.cc"
#include "MStringTokUtil.h"

#define DEBUG_ERRORS		1
#define DEBUG_POSTERIORS	2

/*
 * default value for posterior* weights to indicate they haven't been set
 */
static int version = 0;
static unsigned debug = 0;
static char *vocabFile = 0;
static char *vocabAliasFile = 0;
static int toLower = 0;
static int multiwords = 0;
static const char *multiChar = MultiwordSeparator;
static int nbestBacktrace = 0;
static char *rescoreFile = 0;
static char *nbestFiles = 0;
static char *roverControlFile = 0;
static char *sentid = 0;
static char *writeNbestFile = 0;
static char *writeNbestDir = 0;
static int writeDecipherNbest = 0;
static unsigned maxNbest = 0;
static double rescoreAMW = 1.0;
static double rescoreLMW = 8.0;
static double rescoreWTW = 0.0;
static double posteriorScale = 0.0;
static double posteriorWeight = 1.0;
static int noPosteriors = 0;
static char *writePosteriors = 0;
static int nbestTag = 1;
static int optRest;

static Option options[] = {
    { OPT_TRUE, "version", &version, "print version information" },
    { OPT_UINT, "debug", &debug, "debugging level" },
    { OPT_STRING, "vocab", &vocabFile, "vocab file" },
    { OPT_STRING, "vocab-aliases", &vocabAliasFile, "vocab alias file" },
    { OPT_TRUE, "tolower", &toLower, "map vocabulary to lowercase" },
    { OPT_TRUE, "multiwords", &multiwords, "split multiwords in N-best hyps" },
    { OPT_STRING, "multi-char", &multiChar, "multiword component delimiter" },
    { OPT_TRUE, "nbest-backtrace", &nbestBacktrace, "read backtrace info from N-best lists" },

    { OPT_STRING, "rescore", &rescoreFile, "hyp stream input file to rescore" },
    { OPT_STRING, "nbest", &rescoreFile, "same as -rescore" },
    { OPT_STRING, "nbest-files", &nbestFiles, "list of n-best filenames" },
    { OPT_STRING, "rover-control", &roverControlFile, "process nbest-rover control file" },
    { OPT_STRING, "sentid", &sentid, "sentence ID string for nbest-rover control file" },
    { OPT_STRING, "write-nbest", &writeNbestFile, "output n-best list" },
    { OPT_STRING, "write-nbest-dir", &writeNbestDir, "output n-best directory" },
    { OPT_TRUE, "decipher-nbest", &writeDecipherNbest, "output Decipher n-best format" },
    { OPT_UINT, "max-nbest", &maxNbest, "maximum number of hyps to consider" },
    { OPT_FLOAT, "rescore-amw", &rescoreAMW, "rescoring AM weight" },
    { OPT_FLOAT, "rescore-lmw", &rescoreLMW, "rescoring LM weight" },
    { OPT_FLOAT, "rescore-wtw", &rescoreWTW, "rescoring word transition weight" },
    { OPT_FLOAT, "posterior-scale", &posteriorScale, "divisor for log posterior estimates" },
    { OPT_FLOAT, "posterior-weight", &posteriorWeight, "overall weight of posterior probabilities" },

    { OPT_TRUE, "no-posteriors", &noPosteriors, "do not compute posterior probabilties (acoustic rescoring only)" },
    { OPT_STRING, "write-posteriors", &writePosteriors, "append posteriors probs to file" },
    { OPT_INT, "nbest-tag", &nbestTag, "subsystem tag number for posterior dump" },
    { OPT_REST, "-", &optRest, "indicate end of option list" },
    { OPT_DOC, 0, 0, "following options, an alternating list of weights and score files/directories" },
};

#ifdef _MSC_VER
# include <errno.h>
# include <sys/stat.h>

/*
 * Emulate access(2) in Windows
 */
#define F_OK    0
#define R_OK    4
#define W_OK    2
#define X_OK    1

int
access(const char *path, int mode)
{
    struct _stat buf;

    if (_stat(path, &buf) < 0) {
	return -1;
    } else {
	if (mode & R_OK && !(buf.st_mode & _S_IREAD)) {
	    errno = EPERM;
	    return -1;
	}
	if (mode & W_OK && !(buf.st_mode & _S_IWRITE)) {
	    errno = EPERM;
	    return -1;
	}
	if (mode & X_OK && !(buf.st_mode & _S_IEXEC)) {
	    errno = EPERM;
	    return -1;
	}
	return 0;
    }
}
#endif /* _MSC_VER */


/*
 * Read a list of scores from file
 */
Boolean
readScores(const char *filename, unsigned numHyps, unsigned maxN, Array<LogP2> &scores)
{
    unsigned numScores = 0;

    File file(filename, "r");
    char *line;

    while ((line = file.getline())) {
	LogP2 score;

	if (parseLogP(line, score)) {
	    scores[numScores ++] = score;
	} else {
	    file.position() << "bad score value\n";
	    return false;
	}

	if (maxN > 0 && numScores == maxN) break;
    }

    if (numScores == numHyps || (maxN > 0 && numScores == maxN)) {
	return true;
    } else {
	file.position() << "mismatched number of scores -- expecting "
			<< numHyps << endl;
	return false;
    }
}

/*
 * Process a single N-best list
 */
void
processNbest(Vocab &vocab, const char *sentid,
			const char *nbestFile, unsigned maxN, Prob weight,
			double LMW, double WTW, double postScale,
			unsigned nScores, double scoreWeights[], const char *scoreFiles[], 
			File &outNbestFile, unsigned tag)
{
    /*
     * Process nbest list
     */
    NBestList nbestList(vocab, maxN, multiwords ? multiChar : 0, nbestBacktrace);
    nbestList.debugme(debug);

    /*
     * Posterior scaling:  if not specified (= 0.0) use LMW for
     * backward compatibility.
     */
    if (postScale == 0.0) {
	postScale = (LMW == 0.0) ? 1.0 : LMW;
    }

    if (debug > 0) {
	cerr << "PROCESSING " << nbestFile
	     << " maxn = " << maxN
	     << " weight = " << weight
	     << " lmw = " << LMW << " wtw = " << WTW
	     << " scale = " << postScale
	     << " extras =";
	for (unsigned i = 0; i < nScores; i ++) {
	    cerr << " " << scoreWeights[i]
		 << " " << scoreFiles[i];
	}
	cerr << endl;
    }

    if (nbestFile) {
	File input(nbestFile, "r");

	if (!nbestList.read(input)) {
	    cerr << "format error in nbest list\n";
	    exit(1);
	}
    } else {
	File input(stdin);

	if (!nbestList.read(input)) {
	    cerr << "format error in nbest list\n";
	    exit(1);
	}
    }

    /*
     * Apply AM weight
     */
    if (rescoreAMW != 1.0) {
	for (unsigned i = 0; i < nbestList.numHyps(); i ++) {
	    nbestList.getHyp(i).acousticScore *= rescoreAMW;
	}
    }

    /*
     * Add extra scores into AM score
     */
    for (unsigned j = 0; j < nScores; j ++) {
	if (scoreWeights[j] != 0.0) {
	    Array<LogP2> extraScores;

	    if (!readScores(scoreFiles[j], nbestList.numHyps(), maxN, extraScores)) {
		exit(1);
	    }

	    for (unsigned i = 0; i < nbestList.numHyps(); i ++) {
		nbestList.getHyp(i).acousticScore += scoreWeights[j] * extraScores[i];
	    }
	}
    }

    if (!noPosteriors) {
	/*
	 * compute log posteriors
	 */
	nbestList.computePosteriors(LMW, WTW, postScale, 1.0, true);
	LogP logWeight = ProbToLogP(weight);

	File posteriorFile;
	if (writePosteriors && *writePosteriors) {
	    posteriorFile.reopen(writePosteriors, "a");
	}

	/*
 	 * Encode log posteriors as acoustic scores, for output purposes
 	 * Also, dump posterior to a separate file if requested
 	 */
	for (unsigned i = 0; i < nbestList.numHyps(); i ++) {
	    nbestList.getHyp(i).acousticScore = nbestList.getHyp(i).posterior;
	    nbestList.getHyp(i).languageScore = 0.0;

	    nbestList.getHyp(i).totalScore = nbestList.getHyp(i).acousticScore;

	    if (writePosteriors && *writePosteriors) {
                /* from nbest-posteriors.gawk:
		 * 	print nbest_tag, i, unweighted_logpost >> output_posteriors;
		 */
		posteriorFile.fprintf("%d %d %.*lg\n", tag, i+1,
				Prob_Precision, (double)nbestList.getHyp(i).posterior);
            }
	    nbestList.getHyp(i).acousticScore += logWeight;
	}
    }

    nbestList.write(outNbestFile, writeDecipherNbest);
}

int
main (int argc, char *argv[])
{
    setlocale(LC_CTYPE, "");
    setlocale(LC_COLLATE, "");

    argc = Opt_Parse(argc, argv, options, Opt_Number(options),
							OPT_OPTIONS_FIRST);

    /*
     *  Ensure arguments are in pairs (weight, scorefile)
     */
    if ((argc-1) % 2 == 1) {
	cerr << "number of arguments is not even (alternating weights and score files)\n";
	exit(2);
    }
    unsigned nExtraScores = (argc-1)/2;

    makeArray(double, scoreWeights, nExtraScores);
    makeArray(const char *, scoreFiles, nExtraScores);

    for (unsigned i = 0; i < nExtraScores; i ++) {
	if (sscanf(argv[2*i + 1], "%lf", &scoreWeights[i]) != 1) {
	    cerr << "bad score weight " << argv[2*i + 1] << endl;
	    exit(2);
	}
	scoreFiles[i] = argv[2*i + 2];
    }

    if (version) {
	printVersion(RcsId);
	exit(0);
    }

    Vocab vocab;

    vocab.toLower() = toLower ? true : false;

    if (vocabFile) {
	File file(vocabFile, "r");
	vocab.read(file);
    }

    if (vocabAliasFile) {
	File file(vocabAliasFile, "r");
	vocab.readAliases(file);
    }

    File outFile(stdout);

    /*
     * Process single nbest file
     */
    if (rescoreFile) {
	if (writeNbestFile) {
	    outFile.reopen(writeNbestFile, "w");
	}

	processNbest(vocab, 0, rescoreFile, maxNbest, posteriorWeight,
		     rescoreLMW, rescoreWTW, posteriorScale,
		     nExtraScores, scoreWeights, scoreFiles,
		     outFile, nbestTag);

	if (writeNbestFile) {
	    outFile.close();
	}
    }

    /*
     * Process list of nbest filenames
     */
    if (nbestFiles) {

	File file(nbestFiles, "r");
	char *line;
	while ((line = file.getline())) {
	    char *strtok_ptr = NULL;
	    char *fname = MStringTokUtil::strtok_r(line, wordSeparators, &strtok_ptr);
	    if (!fname) continue;

	    RefString sentid = idFromFilename(fname);

	    /*
	     * Construct score file names from directory path and sentid
	     */
	    makeArray(char *, scoreFileNames, nExtraScores);

	    for (unsigned i = 0; i < nExtraScores; i ++) {
		scoreFileNames[i] = new char[strlen(scoreFiles[i]) + 1 + strlen(sentid) + strlen(GZIP_SUFFIX) + 1];

		sprintf(scoreFileNames[i], "%s/%s%s", scoreFiles[i], sentid,
								GZIP_SUFFIX);
	    }

	    /*
	     * Construct output file names from directory path and sentid
	     */
	    makeArray(char, writeNbestName,
		      (writeNbestDir ? strlen(writeNbestDir) : 0) + 1
				+ strlen(sentid) + strlen(GZIP_SUFFIX) + 1);

	    if (writeNbestDir) {
		sprintf(writeNbestName, "%s/%s%s", writeNbestDir, sentid, GZIP_SUFFIX);

		outFile.reopen(writeNbestName, "r");
	    }

	    processNbest(vocab, sentid, fname, maxNbest, posteriorWeight,
			 rescoreLMW, rescoreWTW, posteriorScale,
			 nExtraScores, scoreWeights, (const char **)(char **)scoreFileNames,
			 outFile, nbestTag);

	    if (writeNbestDir) {
		outFile.close();
	    }

	    for (unsigned i = 0; i < nExtraScores; i ++) {
		delete [] scoreFileNames[i];
	    }
	}
    }

    /*
     * Process rover control file
     */
    if (roverControlFile) {
	if (!sentid) {
	    cerr << "no -sentid specified with rover control file\n";
	    exit(2);
	}

	File roverControl(roverControlFile, "r");

	if (writeNbestFile) {
	    outFile.reopen(writeNbestFile, "w");
	}

	Array<char *> extraScores;
	Array<double> extraWeights;
	unsigned nExtraScores = 0;
	Prob lastWeight = 1.0;

	const char *scoreSuffix = ".score";

	char *line;

	while ((line = roverControl.getline())) {
	    char scoreDir[256], plus[10];
	    double lmw = rescoreLMW, wtw = rescoreWTW, postScale = posteriorScale;
	    unsigned maxN = maxNbest;
	    Prob weight = posteriorWeight;
	    char weightStr[30];
	    unsigned nparsed;

	    /*
	     * nbest-rover:
	     *	read dir lmw wtw weight max_nbest scale rest
	     */
	    if (sscanf(line, "%255s %lf %9s", scoreDir, &lmw, plus) == 3 && strcmp(plus, "+") == 0) {

		extraScores[nExtraScores] = new char[strlen(scoreDir) + 1 + strlen(sentid) + strlen(GZIP_SUFFIX) + 1];
		sprintf(extraScores[nExtraScores], "%s/%s%s", scoreDir, sentid, GZIP_SUFFIX);

		if (access(extraScores[nExtraScores], R_OK) < 0) {
		    sprintf(extraScores[nExtraScores], "%s/%s", scoreDir, sentid);

		    if (access(extraScores[nExtraScores], R_OK) < 0) {
			roverControl.position() << "no score file for sentid " << sentid << endl;

			for (unsigned i = 0; i < nExtraScores; i ++) delete [] extraScores[i];
			nExtraScores = 0;
			continue;
		    }
		}
		extraWeights[nExtraScores] = lmw;

		nExtraScores ++;

	    } else if ((nparsed = sscanf(line, "%255s %lf %lf %29s %u %lf", scoreDir, &lmw, &wtw, weightStr, &maxN, &postScale)) >= 1) {
		char *nbestFile = new char[strlen(scoreDir) + 1 + strlen(sentid) + strlen(scoreSuffix) + strlen(GZIP_SUFFIX) + 1];

		sprintf(nbestFile, "%s/%s%s", scoreDir, sentid, GZIP_SUFFIX);
		if (access(nbestFile, R_OK) < 0) {
		    sprintf(nbestFile, "%s/%s", scoreDir, sentid);

		    if (access(nbestFile, R_OK) < 0) {
			sprintf(nbestFile, "%s/%s%s%s", scoreDir, sentid, scoreSuffix, GZIP_SUFFIX);

			if (access(nbestFile, R_OK) < 0) {
			    sprintf(nbestFile, "%s/%s%s", scoreDir, sentid, scoreSuffix);

			    if (access(nbestFile, R_OK) < 0) {
				roverControl.position() << "no nbest file for sentid " << sentid << endl;

				for (unsigned i = 0; i < nExtraScores; i ++) delete [] extraScores[i];
				nExtraScores = 0;
				delete [] nbestFile;
				continue;
			    }
			}
		    }
		}

		if (nparsed >= 4 && strcmp(weightStr, "=") == 0) {
		    weight = lastWeight;
		} else {
		    if (!parseProb(weightStr, weight)) {
			roverControl.position() << "bad weight value " << weightStr << endl;
			weight = 0.0;
		    }
		    lastWeight = weight;
		}


		
		/*
		 * No combine all the files
		 */
		processNbest(vocab, sentid, nbestFile, maxN, weight,
			     lmw, wtw, postScale,
			     nExtraScores, extraWeights, (const char **)(char **)extraScores,
			     outFile, nbestTag);

		for (unsigned i = 0; i < nExtraScores; i ++) delete [] extraScores[i];
		nExtraScores = 0;
		delete [] nbestFile;

		nbestTag ++;
	    } else {
		roverControl.position() << "bad format in control file\n";

		exit(1);
	    }
	}

	if (writeNbestFile) {
	    outFile.close();
	}
    }

    exit(0);
}

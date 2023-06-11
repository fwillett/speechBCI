#!/usr/bin/perl
#
# Usage: select-vocab [-quiet] -heldout file f1 f2 ... fn 
#
# Selects a vocabulary from the union of the vocabularies of f1
# through fn that maximizes the likelihood of the heldout file.  f1
# through fn can either be text files, count files or ARPA-style
# back-off language models.  If they are text files, further,
# each line in them can optionally be prefixed by a sentence id, which
# will be stripped if the file has the .sentid extension.
#
# Note:  This implementation corrects an error in the paper [1].  The
# EM procedure specification in [1] describes corpus level interpolation.
# But we use word-level interpolation.
#
# Authors: Anand Venkataraman and Wen Wang
# STAR Lab, SRI International, Menlo Park, CA 94025, USA.
#
# $Header: /home/srilm/CVS/srilm/utils/src/select-vocab.pl,v 1.7 2013/04/05 16:50:56 stolcke Exp $
#

# Globals
my $Quiet = 0; # Quiet or Verbose?
my $Gzip = 0;  # Do we have Gzip?

MAIN: {
  my $heldOut = "";      # Filename of the heldout corpus
  my $maxIter = 500;     # Perform a maximum of this many EM iters
  my $precision = 1e-5;  # Stop EM iterations when log likelihood changes less than this much
  my $scale = 1e6;       # Scale final output counts by this much
      
  while ($arg = shift(@ARGV)) {
    if ($arg =~ /^-h(elp)?$/) {
      usage();
    } elsif ($arg =~ /^-held(-)?(out)?$/) {
      $heldOut = shift(@ARGV);
    } elsif ($arg =~ /^-scale(-)?(counts)?$/) {
      $scale = shift(@ARGV);
    } elsif ($arg =~ /^-q(uiet)?$/) {
      $Quiet = 1;
    } elsif ($arg =~ /^-/) {
      print STDERR "Unknown option: $arg\n";
      usage();
    } else {
      unshift(@ARGV, $arg);
      last;
    }
  }
  die "$0: I need a held out corpus (-heldout) to maximize likelihood.\n" if ($heldOut eq "");
  die "$0: I need at least two corpora to combine vocabulary counts.\n" if ($#ARGV < 1);

  # Determine whether gzip exists in the path
  #
  if (system("sh -c 'gzip -help' >/dev/null 2>&1") == 0) {
    message("I found gzip in your path.  So I'll support compressed input.\n");
    $Gzip=1;
  } else {
    message("I didn't find gzip in your path.  So I won't support compressed input.\n");
    $Gzip=0;
  }

  # Make held-out counts and calculate total number of tokens.
  #
  my $heldOut_counts_ref = make_raw_counts($heldOut);
  my $numWords = 0;
  foreach my $word (keys %{$heldOut_counts_ref}) {
    $numWords += $heldOut_counts_ref->{$word};
  }
  die "$0: The held-out corpus must not be empty.\n" if ($numWords == 0);


  # The grand vocab is a union of all possible words, including in the Heldout set.
  #
  my $vocab = make_full_vocab($heldOut, @ARGV);

  # Create log distributions for each of the (n > 1) corpora.  The counts
  # will all use a common vocabulary that is the union of the individual
  # vocabularies.  Use Witten-Bell discounting to handle zero-frequency
  # items in the normalization process.
  #
  for (my $n = 0; $n <= $#ARGV; $n++) {
    $lambda[$n] = 1/($#ARGV+1);
    $logprobs_refs[$n] = estimate_logprobs($ARGV[$n], $vocab);
  }
  message("Iter 0: lambdas = (@lambda)\n");

  # Now perform EM.  Iterate to increase the likelihood of the heldout set.
  # Procedure halts when the likelihood changes by less than $precision
  # after an iteration.  See Eqns. (3)-(6) of Venkataraman & Wang, 2003.
  #
  $done = 0;
  $iter = 0;
  while (!$done && $iter < $maxIter) {
    $done = 1;
    $iter++;

    my $loglike = 0;
    @post_totals = ();

    # Calculate log lambdas.
    # 
    for (my $n = 0; $n <= $#ARGV; $n++) {
      $log_lambda[$n] = log($lambda[$n]);
    }

    # Estimate lambdas per word and average over all words.
    #
    foreach my $word (keys %{$heldOut_counts_ref}) {
      undef $log_numer_sum;

      for (my $n = 0; $n <= $#ARGV; $n++) {
        $log_numer[$n] = $log_lambda[$n] + $logprobs_refs[$n]->{$word};
        $log_numer_sum = logsum($log_numer_sum, $log_numer[$n]);
      }
      $loglike += $log_numer_sum * $heldOut_counts_ref->{$word};

      for (my $n = 0; $n <= $#ARGV; $n++) {
        $post_totals[$n] += exp($log_numer[$n] - $log_numer_sum) * $heldOut_counts_ref->{$word};
      }
    }

    for (my $n = 0; $n <= $#ARGV; $n++) {
      $lambda_prime[$n] = $post_totals[$n]/$numWords;
      $delta[$n] = abs($lambda_prime[$n] - $lambda[$n]);
      $done = 0 if ($delta[$n] > $precision);
    }

    @lambda = @lambda_prime;

    next if $Quiet;
    for (my $n = 0; $n <= $#lambda_prime; $n++) {
      $lambda_trunc[$n] = sprintf("%0.6f", $lambda[$n]);
    }
    my $ppl_trunc = sprintf("%.4f", exp(-$loglike/$numWords));
    my $loglike_trunc = sprintf("%.4f", $loglike);
    message("Iter $iter: lambdas = (@lambda_trunc) log P(held-out) = $loglike_trunc PPL = $ppl_trunc\n");
  }

  # Compute the combined counts.
  #
  message("Combining counts.\n");
  undef %counts;
  foreach my $word (keys %{$vocab}) {
    for (my $n = 0; $n <= $#ARGV; $n++) {
      $counts{$word} += $lambda[$n] * exp($logprobs_refs[$n]->{$word});
    }
  }

  # Print out the final vocab with the combined counts scaled by $scale.
  #
  foreach my $word (keys %counts) {
    my $score = $counts{$word} * $scale;
    print "$word\t $score\n";
  }

  exit(0);
}

#----------------------------------------------------------------------

# Return a ref to a hash of normalized counts.  Use the given vocabulary
# and Witten-Bell (1991) smoothing to ensure non-zero probabilities.
#
sub estimate_logprobs {
  my($f, $voc_ref) = @_;

  message("Estimating logprobs for $f. ");

  my $counts_ref = make_raw_counts($f);

  my $sumcounts = 0;
  foreach my $word (keys %{$counts_ref}) {
    $sumcounts += $counts_ref->{$word};
  }

  # Compute the number of "novel" words. i.e. words in vocab, but
  # not in counts.
  #
  my $vocabsize = scalar keys %{$voc_ref};
  my $nwords = scalar keys %{$counts_ref};
  my $num_novel = $vocabsize - $nwords;
  message("It has all but $num_novel vocabulary words.\n");

  # If there are no novel words, just normalize and return;
  #
  if (!$num_novel) {
    foreach my $word (keys %{$counts_ref}) {
      $counts_ref->{$word} = log($counts_ref->{$word}) - log($sumcounts);
    }
    return $counts_ref;
  }

  # Create keys for novel words.
  #
  foreach my $word (keys %{$voc_ref}) {
    $counts_ref->{$word} += 0;
  }

  # If the sum of the counts is less than zero, we probably got them from a
  # language model that already smoothed the unigram counts.  So we use the left over
  # mass for novel words.  Otherwise, if the sum is equal to 1, we rescale the
  # probabilities by 0.9 (until a better way can be found), and use the remaining
  # mass to distribute.  If the counts are > 1, then we perform smoothing ourselves.
  #
  if ($sumcounts < 1) {
    my $novel_mass = 1-$sumcounts;
    message("\tSum of counts in $f is only $sumcounts\n");
    message("\tWill distribute probabilty mass of $novel_mass over novel words\n");
    my $novel_logprob = log(1-$sumcounts) - log($num_novel);
    foreach my $word (keys %{$counts_ref}) {
      if ($counts_ref->{$word}) {
	$counts_ref->{$word} = log($counts_ref->{$word});
      } else {
	$counts_ref->{$word} = $novel_logprob;
      }
    }
    return $counts_ref;
  }

  if ($sumcounts == 1) {
    message("\tSum of counts in $f is exactly 1\n");
    message("\tWill scale them by 0.9 and use 0.1 for novel words.\n");
    my $novel_logprob = log(0.1/$num_novel);
    foreach my $word (keys %{$counts_ref}) {
      if ($counts_ref->{$word}) {
	$counts_ref->{$word} = log($counts_ref->{$word} * 0.9);
      } else {
	$counts_ref->{$word} = $novel_logprob;
      }
    }
    return $counts_ref;
  }

  # Normalize and smooth.  Note that in calculating the probability of novel words,
  # the Witten-Bell estimate for the novel event is $nwords/($sum_counts+$nwords).
  # This mass is shared equally by each of the novel words and hence $num_novel in
  # the denominator.
  #
  foreach my $word (keys %{$counts_ref}) {
    if ($counts_ref->{$word}) {
      $counts_ref->{$word} = log($counts_ref->{$word}/($sumcounts + $nwords));
    } else {
      $counts_ref->{$word} = log($nwords) - log($sumcounts + $nwords) - log($num_novel);
    }
  }

  return $counts_ref;
}

#---------------------------------------------------------------------------
# The following subroutines construct the vocabulary from various kinds
# of input files.
#
sub make_full_vocab {
  my @files = @_;
  my %voc;

  foreach my $f (@files) {
    $ftype = getftype($f);
    if ($ftype eq "text") {
      message("Adding words from text file $f into vocabulary.\n");
      add_vocab_from_text(\%voc, $f);
    } elsif ($ftype eq "sentid") {
      message("Adding words from sentID file $f into vocabulary.\n");
      add_vocab_from_sentid(\%voc, $f);
    } elsif ($ftype eq "counts") {
      message("Adding words from counts file $f into vocabulary.\n");
      add_vocab_from_counts(\%voc, $f);
    } elsif ($ftype eq "arpa-lm") {
      message("Adding words from ARPA-style LM file $f into vocabulary.\n");
      add_vocab_from_lm(\%voc, $f);
    } else {
      die "I don't know the file type for $f.  Giving up.\n";
    }
  }
  return \%voc;
}

sub add_vocab_from_text {
  my($voc_ref, $f) = @_;

  my $in = zopen($f);
  while (my $line = <$in>) {
    my @words = split(/\s+/, $line);
    foreach my $word (@words) {
      $voc_ref->{$word} = 0;
    }
  }
  close($in);
}

# Same as above, but gets rid of sentid (first word on each line)
#
sub add_vocab_from_sentid {
  my($voc_ref, $f) = @_;

  my $in = zopen($f);
  while (my $line = <$in>) {
    my @words = split(/\s+/, $line);
    shift(@words);                  # Toss sentid
    foreach my $word (@words) {
      $voc_ref->{$word} = 0;
    }
  }
  close($in);
}
 
# Same as above, but only uses the first word of each line.  Each line
# in a count file will have two fields -- word count
#
sub add_vocab_from_counts {
  my($voc_ref, $f) = @_;

  my $in = zopen($f);
  while (my $line = <$in>) {
    my @fields = split(/\s+/, $line);
    next if $line =~ /^\s*$/ || $#fields > 1;   # Ignore non-unigram counts
    next if $fields[0] =~ /<.*>/;               # Skip pseudo words.
    $voc_ref->{$fields[0]} = 0;
  }
  close($in);
}
 
# Same as above, but only takes probabilities from the unigram
# portion of the arpa-format lm.
#
sub add_vocab_from_lm {
  my($voc_ref, $f) = @_;

  my $in = zopen($f);

  # Locate unigram section
  while (my $line = <$in>) {
    last if $line =~ /^\\1-grams:/;
  }

  # Read unigrams into vocab
  while (my $line = <$in>) {
    last if /^\\2-grams:/;
    my ($logprob, $word, @rest) = split(/\s+/, $line);
    next if $word =~ /(^\s*$)|(<.*>)/;                 # Skip pseudo words.
    $voc_ref->{$word} = 0;
  }

  close($in);
}
 
#----------------------------------------------------------------------
# The following subroutines are very similar to the ones above.
# They return a ref to a hash of unnormalized counts from various kinds
# of input files.
#
sub make_raw_counts {
  my($f) = @_;

  $ftype = getftype($f);
  if ($ftype eq "text") {
    return make_raw_counts_from_text($f);
  } elsif ($ftype eq "sentid") {
    return make_raw_counts_from_sentid($f);
  } elsif ($ftype eq "counts") {
    return make_raw_counts_from_counts($f);
  } elsif ($ftype eq "arpa-lm") {
    return make_raw_counts_from_lm($f);
  } else {
    die "I don't know the file type for $f. Giving up.\n";
  }
}

sub make_raw_counts_from_text {
  my($f) = @_;
  my %counts;

  my $in = zopen($f);
  while (my $line = <$in>) {
    my @words = split(/\s+/, $line);
    foreach my $word (@words) {
      $counts{$word}++;
    }
  }
  close($in);
  return \%counts;
}

sub make_raw_counts_from_sentid {
  my($f) = @_;
  my %counts;

  my $in = zopen($f);
  while (my $line = <$in>) {
    my @words = split(/\s+/, $line);
    shift (@words); # Toss sentid
    foreach my $word (@words) {
      $counts{$word}++;
    }
  }
  close($in);
  return \%counts;
}

sub make_raw_counts_from_counts {
  my($f) = @_;
  my %counts;

  my $in = zopen($f);
  while (my $line = <$in>) {
    my @fields = split(/\s+/, $line);
    next if $line =~ /^\s*$/ || $#fields > 1;    # Ignore non-unigram counts.
    next if $fields[0] =~ /<.*>/;                # Skip pseudo words.
    $counts{$fields[0]} += $fields[1];
  }
  close($in);
  return \%counts;
}

# Well, the counts from the lm aren't going to be raw.  We just have to
# settle for the normalized counts.
#
sub make_raw_counts_from_lm {
  my($f) = @_;
  my %counts;

  my $in = zopen($f);

  # Locate unigram section
  while (my $line = <$in>) {
    last if $line =~ /^\\1-grams:/;
  }

  # Read in unigram counts
  while (my $line = <$in>) {
    last if $line =~ /^\\2-grams:/;
    my ($logprob, $word) = split(/\s+/, $line);
    next if $word =~ /(^\s*$)|(<.*>)/;                 # Skip pseudo words.
    $counts{$word} += 10**$logprob;
  }
  close($in);

  return \%counts;
}

#---------------------------------------------------------------------------

sub getftype {
  my($f) = @_;

  # First check if it is a sentid file.  If necessary insert further checks
  # by looking into the file.
  #
  return "sentid" if ($f =~ /\.sentid(\.gz|\.Z)?$/);

  # Extract the first five lines from the file to make our decision.
  #
  my $in = zopen($f);
  for (my $i = 0; $i < 5; $i++)  {
    $lines[$i] = <$in> || last;
  }
  close($in);
  
  # Is it a count file?  Assume it is and try to falsify from the 
  # first 5 lines. Format should be -- word count \n
  #
  my $countfile = 1;
  for (my $i = 0; $i < 5; $i++)  {
    my @words = split(/\s+/, $lines[$i]);
    if ($words[$#words] !~ /\d+/) {
      $countfile = 0;
      last;
    }
  }
  return "counts" if ($countfile == 1);

  # Is it an arpa-style language model?
  #
  my $s = join(' ', @lines);
  return "arpa-lm" if ($s =~ /\s*\\data\\\s*ngram\s+1\s*=/);

  # Otherwise, assume it is a text file.
  #
  return "text";
}

# Given log(x) and log(y), this function returns log(x+y).
#
sub logsum {
  my($x,$y) = @_;
  my $z;
  
  if (!defined($x)) {
    $z = $y;
  } elsif (!defined($y)) {
    $z = $x;
  } else {
    $z = ($x < $y)? logsum($y,$x) : $x + log(1+exp($y-$x));
  }
  return $z;
}

sub message {
  my($msg) = @_;

  return if ($Quiet);
  print STDERR "$msg";
}

# Opens a possibly compressed file.  Only uncomment the gzip line
# if gzip is available.  Otherwise, compressed files aren't supported.
#
sub zopen {
  my($f) = @_;
  local *IN;
  
  die "$f is not a file.\n" if ! -f $f;

  if (!$Gzip) {
    open(IN, $f) || die "$f: $!\n";
  } else {
    open(IN, "gzip -dfc $f |") || die "gzip -dfc $f: $!\n";
  }

  return *IN;
}

sub usage {
  print STDERR <<"  .;";

    Usage:
      $0 [-quiet] [-scale n] -heldout corp_h corp1 corp2 ...

    Estimate weighted and combined counts for the words in the vocabulary.
    These weights maximize the likelihood of the heldout corpus, corp_h, by
    the Witten-Bell smoothed mixture unigram language models from corp_1 through
    corp_n.

    -quiet stops debug style messages while running.
    -scale n causes final combined counts to be scaled by n.

  .;

  exit 1;
}

#---------------------------------------------------------------------------------
# References.
#
# 1. Venkataraman, A. and W. Wang, (2003).  "Techniques for effective vocabulary
#    selection", in Proceedings of Eurospeech'03, Geneva, 2003.
#
# 2. Witten, I. H. and T. C. Bell, (1991). "The zero-frequency problem:
#    Estimating the probabilities of novel events in adaptive text compression",
#    IEEE Trans. IT, 37, pp. 1085-1091.

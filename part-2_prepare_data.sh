#!/bin/bash

# echo 'Cloning Moses github repository (for tokenization scripts)...'
# git clone https://github.com/moses-smt/mosesdecoder.git

# echo 'Cloning Subword NMT repository (for BPE pre-processing)...'
# git clone https://github.com/rsennrich/subword-nmt.git

SCRIPTS=mosesdecoder/scripts
TOKENIZER=$SCRIPTS/tokenizer/tokenizer.perl
CLEAN=$SCRIPTS/training/clean-corpus-n.perl
NORM_PUNC=$SCRIPTS/tokenizer/normalize-punctuation.perl
REM_NON_PRINT_CHAR=$SCRIPTS/tokenizer/remove-non-printing-char.perl

src=fr
tgt=en
lang=fr-en
prep=fr-en-part2
tmp=$prep/tmp

data_path='fr-en/train'
dev_path='fr-en/IWSLT13.TED.dev2010.fr-en'
test_path='fr-en/IWSLT13.TED.tst2010.fr-en'


echo "pre-processing train data..."

for l in $src $tgt; do 
    cat $data_path.$l | perl $NORM_PUNC $l | perl $REM_NON_PRINT_CHAR | perl $TOKENIZER -threads 8 -a -l $l >> fr-en/train.tags.$lang.tok.$l
done

echo "pre-processing dev data..."

for l in $src $tgt; do
    grep '<seg id' $dev_path.$l.xml | \
        sed -e 's/<seg id="[0-9]*">\s*//g' | \
        sed -e 's/\s*<\/seg>\s*//g' | \
        sed -e "s/\’/\'/g" | \
    perl $TOKENIZER -threads 8 -a -l $l > fr-en/valid.$l
done

echo "pre-processing test data..."

for l in $src $tgt; do
    grep '<seg id' $test_path.$l.xml | \
        sed -e 's/<seg id="[0-9]*">\s*//g' | \
        sed -e 's/\s*<\/seg>\s*//g' | \
        sed -e "s/\’/\'/g" | \
    perl $TOKENIZER -threads 8 -a -l $l > fr-en/test.$l
done

echo 'Data Preparation completed'

# run fairseq-preprocess

mkdir fr-en/moses_preprocessed

TEXT=fr-en
echo 'Running fairseq-preprocess'
fairseq-preprocess \
    --source-lang fr --target-lang en \
    --trainpref $TEXT/train --validpref $TEXT/valid --testpref $TEXT/test \
    --destdir fr-en/moses_preprocessed --thresholdtgt 0 --thresholdsrc 0 \
    --workers 60

echo 'fairseq-preprocess completed'




#!/bin/bash

echo 'Cloning Moses github repository (for tokenization scripts)...'
git clone https://github.com/moses-smt/mosesdecoder.git

echo 'Cloning Subword NMT repository (for BPE pre-processing)...'
git clone https://github.com/rsennrich/subword-nmt.git

SCRIPTS=mosesdecoder/scripts
TOKENIZER=$SCRIPTS/tokenizer/tokenizer.perl
CLEAN=$SCRIPTS/training/clean-corpus-n.perl
NORM_PUNC=$SCRIPTS/tokenizer/normalize-punctuation.perl
REM_NON_PRINT_CHAR=$SCRIPTS/tokenizer/remove-non-printing-char.perl
BPEROOT=subword-nmt/subword_nmt
BPE_TOKENS=10000

src=fr
tgt=en
lang=fr-en
prep=fr-en
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
    perl $TOKENIZER -threads 8 -a -l $l > fr-en/dev.$l
done

echo "pre-processing test data..."

for l in $src $tgt; do
    grep '<seg id' $test_path.$l.xml | \
        sed -e 's/<seg id="[0-9]*">\s*//g' | \
        sed -e 's/\s*<\/seg>\s*//g' | \
        sed -e "s/\’/\'/g" | \
    perl $TOKENIZER -threads 8 -a -l $l > fr-en/test.$l
done


TRAIN=fr-en/train.fr-en
BPE_CODE=$prep/code
echo $BPE_CODE
rm -f $TRAIN
for l in $src $tgt; do
    cat fr-en/train.$l >> $TRAIN
done

echo "learn_bpe.py on ${TRAIN}..."
python $BPEROOT/learn_bpe.py -s $BPE_TOKENS < $TRAIN > $BPE_CODE

for L in $src $tgt; do
    for f in train.$L dev.$L test.$L; do
        echo "apply_bpe.py to ${f}..."
        python $BPEROOT/apply_bpe.py -c $BPE_CODE < fr-en/$f > fr-en/tokenized_fr-en/bpe.$f
    done
done

perl $CLEAN -ratio 1.5 fr-en/tokenized_fr-en/bpe.train $src $tgt fr-en/tokenized_fr-en/train 1 250
perl $CLEAN -ratio 1.5 fr-en/tokenized_fr-en/bpe.dev $src $tgt fr-en/tokenized_fr-en/valid 1 250

for L in $src $tgt; do
    cp fr-en/tokenized_fr-en/bpe.test.$L fr-en/tokenized_fr-en/test.$L
done
echo 'Data Preparation completed'

# run fairseq-preprocess

TEXT=fr-en/tokenized_fr-en
echo 'Running fairseq-preprocess'
fairseq-preprocess \
    --source-lang fr --target-lang en \
    --trainpref $TEXT/train --validpref $TEXT/valid --testpref $TEXT/test \
    --destdir fr-en/preprocessed --thresholdtgt 0 --thresholdsrc 0 \
    --workers 60

echo 'fairseq-preprocess completed'




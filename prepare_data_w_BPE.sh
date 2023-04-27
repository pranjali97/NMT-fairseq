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
BPE_TOKENS=40000

CORPORA=(
    "fr-en/train.tags.fr-en"
)

if [ ! -d "$SCRIPTS" ]; then
    echo "Please set SCRIPTS variable correctly to point to Moses scripts."
    exit
fi


src=fr
tgt=en
lang=fr-en
prep=iwslt13_fr_en
tmp=$prep/tmp
orig=data

mkdir -p $orig $tmp $prep

echo "grep dev data..."
for l in $src $tgt; do
    grep '<seg id' $orig/"fr-en/IWSLT13.TED.dev2010.fr-en".$l.xml | \
        sed -e 's/<seg id="[0-9]*">\s*//g' | \
        sed -e 's/\s*<\/seg>\s*//g' | \
        sed -e "s/\’/\'/g" | \
    perl $TOKENIZER -threads 8 -a -l $l > $orig/iwslt13.dev.$l
    echo ""
done

echo "grep test data..."
for l in $src $tgt; do
    grep '<seg id' $orig/"fr-en/IWSLT13.TED.tst2010.fr-en".$l.xml | \
        sed -e 's/<seg id="[0-9]*">\s*//g' | \
        sed -e 's/\s*<\/seg>\s*//g' | \
        sed -e "s/\’/\'/g" | \
    perl $TOKENIZER -threads 8 -a -l $l > $orig/iwslt13.test.$l
    echo ""
done

echo "pre-processing train data..."
for l in $src $tgt; do
    rm $tmp/train.$l
    for f in "${CORPORA[@]}"; do
        cat $orig/$f.$l |
            perl $NORM_PUNC $l |
            perl $REM_NON_PRINT_CHAR |
            perl $TOKENIZER -threads 8 -a -l $l >>$tmp/train.$l
    done
done

echo "pre-processing dev data..."
for l in $src $tgt; do
    cat $orig/iwslt13.dev.$l |
        perl $TOKENIZER -threads 8 -a -l $l >$tmp/dev.$l
    echo ""
done

echo "pre-processing test data..."
for l in $src $tgt; do
    cat $orig/iwslt13.test.$l |
        perl $TOKENIZER -threads 8 -a -l $l >$tmp/test.$l
    echo ""
done


TRAIN=$tmp/train.fr-en
BPE_CODE=$prep/code
rm -f $TRAIN
for l in $src $tgt; do
    cat $tmp/train.$l >>$TRAIN
done


echo "learn_bpe.py on ${TRAIN}..."
python3 $BPEROOT/learn_bpe.py -s $BPE_TOKENS <$TRAIN >$BPE_CODE

for L in $src $tgt; do
    for f in train.$L dev.$L test.$L; do
        echo "apply_bpe.py to ${f}..."
        python3 $BPEROOT/apply_bpe.py -c $BPE_CODE < $tmp/$f > $tmp/bpe.$f
    done
done

perl $CLEAN -ratio 1.5 $tmp/bpe.train $src $tgt $prep/train 1 250
perl $CLEAN -ratio 1.5 $tmp/bpe.dev $src $tgt $prep/dev 1 250

for L in $src $tgt; do
    cp $tmp/bpe.test.$L $prep/test.$L
done


fairseq-preprocess \
    --source-lang fr --target-lang en \
    --trainpref iwslt13_fr_en/train --validpref iwslt13_fr_en/dev --testpref iwslt13_fr_en/test \
    --destdir fr-en/moses_preprocessed --thresholdtgt 0 --thresholdsrc 0 \
    --workers 60
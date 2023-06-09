#!/bin/bash

# running fairseq-train
echo 'Running Fairseq-train'
mkdir checkpoints/fconv

fairseq-train \
    fr-en/preprocessed \
    --arch fconv \
    --dropout 0.1 \
    --criterion label_smoothed_cross_entropy --label-smoothing 0.1 \
    --optimizer nag --clip-norm 0.1 \
    --lr 0.5 --lr-scheduler fixed --force-anneal 50 \
    --max-tokens 3000 --max-epoch 2 --save-dir checkpoints/fconv

# # Evaluate
fairseq-generate \
    fr-en/preprocessed \
    --path checkpoints/fconv/checkpoint_best.pt \
    --scoring sacrebleu \
    --beam 5 --remove-bpe

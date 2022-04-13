#!/bin/bash

feature=$1
part=$2
if [[ -n $(git status --porcelain) ]]; then
   git config --global user.name 'github-actions[bot]' 
   git config --global user.email 'github-actions[bot]@users.noreply.github.com' 
   git repack -a -d --depth=250 --window=250
   git add -A
   git commit -sam "[UPSTREAM] $feature $part" || exit 0
   git push
fi

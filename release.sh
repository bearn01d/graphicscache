#!/bin/bash

set -ex

# source: https://stackoverflow.com/questions/29436275/how-to-prompt-for-yes-or-no-in-bash
function yes_or_no {
  while true; do
    read -p "$* [y/n]: " yn
    case $yn in
      [Yy]*) return 0  ;;
      [Nn]*) echo "Aborted" ; return  1 ;;
    esac
  done
}

err_report() {
  echo
  echo
  echo "release.sh:$1: ERROR: Some command failed (see above)"
  exit 1
}

trap 'err_report $LINENO' ERR

if [[ $# -ne 1 ]]; then
  echo "Usage: release.sh input.tex"
  exit 1
fi

if [[ -e submission.tex ]] && [[ $1 -ef submission.tex ]]; then
  echo "Your file is named 'submission.tex' and I would overwrite it. Aborting..."
  exit 1
fi

echo "1) Running latexpand to strip comments and unify your .tex file..."
latexpand --empty-comments $1 > submission.tex

echo
echo "2) Running pdflatex..."
pdflatex -shell-escape -interaction nonstopmode submission.tex
pdflatex -shell-escape -interaction nonstopmode submission.tex
bibtex submission
pdflatex -shell-escape -interaction nonstopmode submission.tex
pdflatex -shell-escape -interaction nonstopmode submission.tex

echo
echo "3) Running pdflatex with render=false to determine needed files..."
mv submission.tex submission.tex.orig
echo '\makeatletter\def\graphicscache@inhibit{true}\makeatother' > submission.tex
cat submission.tex.orig >> submission.tex
pdflatex -interaction nonstopmode -recorder submission.tex

FILES=$(grep "^INPUT" submission.fls | cut -d ' ' --complement -f 1 | grep -v '^/' | grep -v 'submission\..*' | sort | uniq)
FILES="$FILES submission.tex"

if [[ -e submission.bbl ]]; then
  FILES="$FILES submission.bbl"
fi

# Some of the files are ./XYZ, some are XYZ
CLEAN_FILES=""
for file in $FILES; do
	CLEAN_FILES="$CLEAN_FILES $(realpath --relative-to=. $file)"
done

FILES=$(echo $CLEAN_FILES | tr ' ' '\n' | sort -u)

echo "Files to be included:"
echo $FILES

echo "4) Creating archive release.tar..."
tar cf release.tar $FILES

echo "5) Testing compilation..."
if [[ -e test_release ]]; then
  if yes_or_no "The output directory test_release already exists. Can I remove it (rm -Rf test_release)?"; then
    rm -Rf test_release
  else
    exit 1
  fi
fi

(
  mkdir test_release
  cd test_release
  tar xf ../release.tar
  pdflatex -interaction nonstopmode submission.tex
  pdflatex -interaction nonstopmode submission.tex
  pdflatex -interaction nonstopmode submission.tex
)

echo
echo "Finished. Please check test_release/submission.pdf for correctness."

# Clean up intermediate files
rm -f submission.pdf submission.out submission.aux submission.log submission.fls
rm -f submission.blg submission.bbl submission.tex.orig


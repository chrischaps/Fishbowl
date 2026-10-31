#!/usr/bin/env sh
# Packs the tank as dist/fishbowl.love, with dist/SHA256SUMS beside it, for
# Easel to fetch (chrischaps/easel#35):
#
#   sh scripts/package.sh            (HEAD)
#   sh scripts/package.sh v0.1.0     (any commit or tag)
#
# The .love is a git archive of one commit, so only what's committed ships,
# never an uncommitted edit or a folder of snaps. Left out is what only a
# developer runs or reads: tests/, scripts/, CI, the screenshot and the
# notes. Easel checks the download against SHA256SUMS before it puts the
# tank on the frame.

cd "$(dirname "$0")/.." || exit 1
ref=${1:-HEAD}

mkdir -p dist
rm -f dist/fishbowl.love dist/SHA256SUMS
git archive --format=zip -9 -o dist/fishbowl.love "$ref" -- . \
    ':(exclude)tests' ':(exclude)scripts' ':(exclude).github' ':(exclude).claude' \
    ':(exclude).gitignore' ':(exclude).gitattributes' ':(exclude)Screenshot.png' \
    ':(exclude,glob)**/*.md' || exit 1
# (the sed keeps Git Bash's binary-mode '*' out, so it reads as on Linux)
(cd dist && sha256sum fishbowl.love | sed 's/ \*/  /' > SHA256SUMS) || exit 1

echo "packed $(git rev-parse --short "$ref") as dist/fishbowl.love"
cat dist/SHA256SUMS

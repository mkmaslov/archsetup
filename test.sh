#!/bin/bash

set -e

VERSION=$(\
  curl -sL https://api.github.com/repos/textext/textext/releases/latest | \
  jq -r ".tag_name")
LINK="https://github.com/textext/textext/releases/download/"
LINK+="${VERSION}/TexText-Linux-${VERSION}.tar.gz"
echo ${LINK}
#!/usr/bin/env bash
set -e
# Limpa builds anteriores e gera o ISO padrão
sudo rm -rf out/ work/
sudo mkarchiso -v -w work/ -o out/ profile/

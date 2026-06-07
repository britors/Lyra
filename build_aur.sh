#!/bin/bash
set -e

REPO_DIR="lyra_profile/repo/x86_64"
mkdir -p "$REPO_DIR"

# Build yay-bin
echo "Building yay-bin..."
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -s --noconfirm
cp *.pkg.tar.zst ../$REPO_DIR/
cd ..
rm -rf yay-bin

# Build prosa
echo "Building prosa..."
git clone https://aur.archlinux.org/prosa.git
cd prosa
makepkg -s --noconfirm
cp *.pkg.tar.zst ../$REPO_DIR/
cd ..
rm -rf prosa

# Build fina
echo "Building fina..."
git clone https://aur.archlinux.org/fina.git
cd fina
makepkg -s --noconfirm
cp *.pkg.tar.zst ../$REPO_DIR/
cd ..
rm -rf fina

# Build calamares
echo "Building calamares..."
git clone https://aur.archlinux.org/calamares.git
cd calamares
makepkg -s --noconfirm
cp *.pkg.tar.zst ../$REPO_DIR/
cd ..
rm -rf calamares

# Update repo database
cd $REPO_DIR
repo-add lyra.db.tar.gz *.pkg.tar.zst
cd ../../..

echo "All packages built and added to the local repository."

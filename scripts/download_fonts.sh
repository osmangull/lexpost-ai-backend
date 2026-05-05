#!/bin/bash
# Download Playfair Display and Montserrat fonts from Google Fonts
# Run from project root: bash scripts/download_fonts.sh

set -e

FONTS_DIR="backend/assets/fonts"
mkdir -p "$FONTS_DIR"

echo "Downloading Playfair Display..."
curl -sL "https://fonts.google.com/download?family=Playfair+Display" -o /tmp/playfair.zip
unzip -j -o /tmp/playfair.zip "*.ttf" -d "$FONTS_DIR"

echo "Downloading Montserrat..."
curl -sL "https://fonts.google.com/download?family=Montserrat" -o /tmp/montserrat.zip
unzip -j -o /tmp/montserrat.zip "*.ttf" -d "$FONTS_DIR"

# Keep only the variants the engine uses
cd "$FONTS_DIR"
for f in *.ttf; do
  case "$f" in
    PlayfairDisplay-Bold.ttf | PlayfairDisplay-Regular.ttf | Montserrat-Bold.ttf | Montserrat-Regular.ttf)
      ;;
    *)
      rm "$f"
      ;;
  esac
done

echo "Fonts ready in $FONTS_DIR:"
ls "$FONTS_DIR"

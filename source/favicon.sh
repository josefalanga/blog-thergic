#!/bin/bash
iconpath=$(realpath arise-icon.png)
cd config/favicon
convert $iconpath -resize 192x android-chrome-192x192.png
convert $iconpath -resize 256x android-chrome-256x256.png
convert $iconpath -resize 180x apple-touch-icon.png
convert $iconpath -resize 48x favicon.ico
convert $iconpath -resize 16x favicon-16x16.png
convert $iconpath -resize 32x favicon-32x32.png
convert $iconpath -resize 150x mstile-150x150.png
#grab it from the svg
#convert iconpath -resize 192x safari-pinned-tab.svg
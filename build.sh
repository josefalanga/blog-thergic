#!/bin/bash
echo "starting"
echo "git clone https://github.com/josefalanga/uprise.git"
git clone https://github.com/josefalanga/uprise.git
bash uprise/arise build source public
rm -rf uprise

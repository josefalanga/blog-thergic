#!/bin/bash
sudo apt-get install -y pandoc
git clone https://github.com/josefalanga/uprise.git
bash uprise/arise build source public
rm -rf uprise

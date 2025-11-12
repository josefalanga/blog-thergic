#!/bin/bash
git clone https://github.com/josefalanga/uprise.git
bash uprise/arise build source public
rm -rf uprise

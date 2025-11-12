#!/bin/bash
rm -rf public
git clone https://github.com/josefalanga/uprise.git
bash uprise/arise build source public

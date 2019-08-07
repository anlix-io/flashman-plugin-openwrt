#!/bin/sh

gcc -std=c99 -ggdb testdetectddos.c ../detectddos.c -I../ -lm -lrt -o testdetectddos

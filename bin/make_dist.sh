#!/bin/sh
# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.3* version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

./bin/make_doc.sh

mv -f data/*.txt examples
rm -f data/*
mv -f spool/*	 examples
rm -rf blib Makefile pm_to_blib

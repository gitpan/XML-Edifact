#!/bin/sh
# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.3* version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

./bin/create_dtd.pl >spool/edifact03.dtd

for x in examples/*.edi
do
	echo processing $x
	./bin/edi2xml.pl $x >spool/`basename $x .edi`.xml
done

for x in spool/*
do
	diff $x examples/`basename $x` >/dev/null || echo $x changed
done

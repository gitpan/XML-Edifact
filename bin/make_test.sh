#!/bin/sh
# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.2 version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

rm -f data/*

./bin/create_codes.pl
./bin/create_segment.pl
./bin/create_composite.pl
./bin/create_element.pl
./bin/add_annex_b.pl
./bin/patch_tables.pl

./bin/create_dtd.pl >spool/edicooked02.dtd

for x in examples/*.edi
do
	echo processing $x
	./bin/edi2xml.pl $x >spool/`basename $x .edi`.xml
done

for x in spool/*
do
	diff $x examples/`basename $x` >/dev/null || echo $x changed
done

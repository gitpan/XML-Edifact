#!/usr/local/bin/perl
# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.2 version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

use XML::Edifact;
use Fcntl;
use strict;

use vars qw($segm $segmt $segmn @segmv $segments);
use vars qw($elem $elemt);
use vars qw($debug $mark $oldmark);

$debug=2;

# -----------------------------------------------------------------------------
printf "patching elements!!!\n";

&XML::Edifact::open_dbm("data",O_RDWR);
&XML::Edifact::open_num("data");

$segments=" ";
foreach $segm (sort(keys %XML::Edifact::SEGMN)) {
	$segmn=$XML::Edifact::SEGMN{$segm};
	$segmt=$XML::Edifact::SEGMT{$segm."\t0"};
	@segmv=split('\t', $segmt, 4);
	$mark =&XML::Edifact::recode_mark($segmv[3]);
	$segments .= $mark." ";
}

foreach $elem (sort(keys %XML::Edifact::ELEMT)) {
	$elemt=$XML::Edifact::ELEMT{$elem};
	$mark =&XML::Edifact::recode_mark($elemt);
	$oldmark = $mark;
	
	if ($segments =~ / $mark /) {
		$mark .= ".literal";
		printf "%s %s %s\n", $elem, $oldmark, $mark;
		$XML::Edifact::ELEMT{$elem}=$mark;
	}
}

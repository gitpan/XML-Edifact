#!/usr/local/bin/perl
# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.2 version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

=head1 NAME

add_annex_b - read Annex B from D422 to patch segment and composite data

=head1 SYNOPSIS

./bin/add_annex_b.pl

=head1 DESCRIPTION

This script can run after create_{segment,composite,codes}.pl
but before create_dtd.pl to add segments and composites from Annex B.

You wont normaly find a file called Annex_B in the
EDIFACT documentation. Its part of D422, but as this file was'nt
parseable I took the work to reformat Annex B into a new file,
powerd by vi because I needed natural intelligence to prepare
the artificial stupidity of this script.

Most of the work wont be neccessary, if they've written XML.

=cut

use SDBM_File;
use XML::Edifact;
use Fcntl;

tie(%SEGMT, 'SDBM_File', 'data/segment.tie', O_RDWR, 0640)	|| die "can not tie composite.tie:".$!;
tie(%SEGMN, 'SDBM_File', 'data/segment.num', O_RDWR, 0640)	|| die "can not tie composite.num:".$!;
tie(%COMPT, 'SDBM_File', 'data/composite.tie', O_RDWR, 0640)	|| die "can not tie composite.tie:".$!;
tie(%COMPN, 'SDBM_File', 'data/composite.num', O_RDWR, 0640)	|| die "can not tie composite.num:".$!;
tie(%ELEMT, 'SDBM_File', 'data/element.tie', O_RDWR, 0640)	|| die "can not tie element.tie:".$!;

open (INFILE, "un_edifact_d96b/annex_b.96b") || die "can not open annex_b.96b for reading";
open (SEGFILE, ">data/segment.add") || die "can not open segment.txt for writing";
open (COMFILE, ">data/composite.add") || die "can not open segment.txt for writing";
open (ELEFILE, ">data/element.add") || die "can not open segment.txt for writing";

printf STDERR "reading Annex B\n";

while (<INFILE>) {
    chop;	# strip record separator
    if (!($. % 64)) {
	printf STDERR '.';
    }
    if (/^Segment: ..., /) {
	$tag=substr($_,9,3);
	$fnr=0;
	$cod="";
	$des=substr($_,14);
	$man="";
	$typ="";
	$comptag="";
	printf SEGFILE "%s\t%s\t%s\t%s\t%s\t%s\n", $tag, $fnr, $cod, $man, $typ, $des;
	$SEGMT{$tag."\t".$fnr}=$cod."\t".$man."\t".$typ."\t".$des;
	$SEGMN{$tag}=$fnr;
    }
    if (/^ [S0-9][0-9][0-9][0-9] /) {
	$cod=substr($_,1,4);
	$typ=substr($_,8,7);
	$man=substr($_,16,1);
	$des=substr($_,20);
        if ($comptag eq "") {
	    $fnr++;
	    printf SEGFILE "%s\t%s\t%s\t%s\t%s\t%s\n", $tag, $fnr, $cod, $man, $typ, $des;
	    $SEGMT{$tag."\t".$fnr}=$cod."\t".$man."\t".$typ."\t".$des;
	    $SEGMN{$tag}=$fnr;
	    $comptag=$cod;
	    $compdes=$des;
	    $cnr=1;
    	} else {
    	    if ($cnr==1) {
	        printf COMFILE "%s\t%s\t%s\t%s\t%s\t%s\n", $comptag, 0, "", "", "", $compdes;
		$COMPT{$comptag."\t0"}="\t\t\t".$compdes;
		$COMPN{$comptag}=0;
	    }
	    printf COMFILE "%s\t%s\t%s\t%s\t%s\t%s\n", $comptag, $cnr, $cod, $man, $typ, $des;
	    $COMPT{$comptag."\t".$cnr}=$cod."\t".$man."\t".$typ."\t".$des;
 	    $COMPN{$comptag}=$cnr;
	    $cnr++;
        }
        if (($cod =~ /^[0-9]/) && ($ELEMT{$cod} eq "")) {
	    $des = &XML::Edifact::recode_mark($des);
	    printf ELEFILE "%s\t%s\n", $cod, $des;
	    $ELEMT{$cod}=$des;
	}
    }
    $comptag="" if (/^[ =_-]+$/);
}

close(INFILE);
close(SEGFILE);
close(COMFILE);
print STDERR "\n";

untie(%COMPT);
untie(%COMPN);
untie(%SEGMT);
untie(%SEGMN);

0;

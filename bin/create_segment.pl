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

create_segment - read trsd to create segment data

=head1 SYNOPSIS

./bin/create_segment.pl

=head1 DESCRIPTION

Read TRSD to create segment.txt and segment.dat for further processing

=cut

use SDBM_File;
use Fcntl;

tie(%SEGMT, 'SDBM_File', 'data/segment.tie', O_RDWR|O_CREAT, 0640)	|| die "can not tie composite.tie:".$!;
tie(%SEGMN, 'SDBM_File', 'data/segment.num', O_RDWR|O_CREAT, 0640)	|| die "can not tie composite.num:".$!;

open (INFILE, "un_edifact_d96b/trsd.96b") || die "can not open trsd.96b for reading";
open (OUTFILE, ">data/segment.txt") || die "can not open segment.txt for writing";

printf STDERR "reading trsd.96b\n";

while (<INFILE>) {
    chop;	# strip record separator
    if (!($. % 64)) {
	printf STDERR '.';
    }
    $f3 = substr($_,6,4);
    $f5 = substr($_,12,46);
    $f7 = substr($_,59,1);
    $f9 = substr($_,62,7);

    $ok = 0;

    if ($_ =~ '^   [+*#|X -][+*#|X -] [A-Z][A-Z][A-Z]   ') {
	$tag = $f3;
	$s = " \$", $tag =~ s/$s//;
	$cod = '';
	$des = $f5;
	$s = '^ *', $des =~ s/$s//;
	$s = " *\$", $des =~ s/$s//;
	$fnr = 0;
	$man = '';
	$typ = '';
	$ok = 1;
    }

    if ($_ =~ '^[0-9][0-9][0-9] [+*#|X -] ') {
	$cod = $f3;
	$des = $f5;
	$s = '^ *', $des =~ s/$s//;
	$s = " *\$", $des =~ s/$s//;
	$fnr++;
	$man = $f7;
	$typ = $f9;
	$ok = 1;
    }

    if ($ok) {
	printf OUTFILE "%s\t%s\t%s\t%s\t%s\t%s\n", $tag, $fnr, $cod, $man, $typ, $des;
	$SEGMT{$tag."\t".$fnr}=$cod."\t".$man."\t".$typ."\t".$des;
	$SEGMN{$tag}=$fnr;
    }
}

close(INFILE);
close(OUTFILE);

untie %SEGMT;
untie %SEGMN;
print STDERR "\n";

0;

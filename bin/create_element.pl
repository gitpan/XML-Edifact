#!/usr/local/bin/perl
# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.3* version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

=head1 NAME

create_element - read tred to create element data

=head1 SYNOPSIS

./bin/create_element.pl

=head1 DESCRIPTION

Read TRED to create element.txt and element.dat for further processing

=cut

use XML::Edifact;
use SDBM_File;
use Fcntl;

tie(%ELEMT, 'SDBM_File', 'data/element.dat', O_RDWR|O_CREAT, 0640)	|| die "can not tie composite.dat:".$!;
open (OUTFILE, ">data/element.txt") || die "can not open element.txt for writing";

printf STDERR "reading tred.96b\n";
open (INFILE, "un_edifact_d96b/tred.96b") || die "can not open tred for reading";
while (<INFILE>) {
    chop;	# strip record separator
    if (!($. % 64)) {
	printf STDERR '.';
    }

    if ($_ =~ '^[+*#|X -][+*#|X -] [0-9][0-9][0-9][0-9]  ') {
	$cod = substr($_, 3, 4);
	$des = substr($_, 9);

	$des = &XML::Edifact::recode_mark($des);

	printf OUTFILE "%s\t%s\n", $cod, "tred:".$des;

	$ELEMT{$cod}="tred:".$des;
    }
}
close(INFILE);
close(OUTFILE);
untie %ELEMT;
print STDERR "\n";

0;

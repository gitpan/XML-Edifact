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

create_codes - read uncl to create code data

=head1 SYNOPSIS

./bin/create_codes.pl

=head1 DESCRIPTION

Read UNCL to create codes.txt and codes.dat for further processing

=cut

use SDBM_File;
use Fcntl;

tie(%CODET, 'SDBM_File', 'data/codes.tie', O_RDWR|O_CREAT, 0640)	|| die "can not tie composite.tie:".$!;
tie(%CODEN, 'SDBM_File', 'data/codes.num', O_RDWR|O_CREAT, 0640)	|| die "can not tie composite.num:".$!;

open (OUTFILE, ">data/codes.txt") || die "can not open codes.txt for writing";

open (INFILE, "un_edifact_d96b/uncl-1.96b") || die "can not open uncl-1.96b for reading";
printf STDERR "reading uncl-1.96b\n";
while (<INFILE>) { read_code(); };
close(INFILE);
print STDERR "\n";

open (INFILE, "un_edifact_d96b/uncl-2.96b") || die "can not open uncl-2.96b for reading";
printf STDERR "reading uncl-2.96b\n";
while (<INFILE>) { read_code(); };
close(INFILE);
print STDERR "\n";

open (INFILE, "un_edifact_d96b/unsl.96b") || die "can not open unsl.96b for reading";
printf STDERR "reading unsl.96b\n";
while (<INFILE>) { read_code(); };
close(INFILE);
print STDERR "\n";

close(OUTFILE);

untie %CODET;
untie %CODEN;

sub read_code {
    chop;	# strip record separator
    if (!($. % 64)) {
	printf STDERR '.';
    }

    $ok = 0;

    if ($_ =~ '^[+*#|X -] [0-9][0-9][0-9][0-9]  ') {
	$cod = substr($_, 2, 4);
	$des = substr($_, 8);
	$s = '^ *', $des =~ s/$s//;
	$s = " *\$", $des =~ s/$s//;
	$fld = '';
	$ok = 1;
    }
    elsif (($_ =~ '^[+*#|X -][+*#|X -] [0-9A-Z ][0-9A-Z ][0-9A-Z ][0-9A-Z ][0-9A-Z ][0-9A-Z] ')
        || ($_ =~ '^[+*#|X -][+*#|X -] [0-9A-Z][0-9A-Z ][0-9A-Z ][0-9A-Z ][0-9A-Z ][0-9A-Z ] '))

      {
	$fld = substr($_, 3, 6);
	$s = ' ', $fld =~ s/$s//g;
	$des = substr($_, 10);
	$s = '^ *', $des =~ s/$s//;
	$s = " *\$", $des =~ s/$s//;
	$ok = 1;
    }

    if ($ok) {
	printf OUTFILE "%s\t%s\t%s\n", $cod, $fld, $des;

	$CODET{$cod."\t".$fld}=$des;

	$codn=0 if ($oldcod ne $cod);
	$oldcod=$cod;
	$codn++;
	$CODEN{$cod}=$codn;
    }
}

0;

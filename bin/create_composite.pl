#!/usr/local/bin/perl
# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.30 version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!
#------------------------------------------------------------------------------#

=head1 NAME

create_composite - read trcd to create composite data

=head1 SYNOPSIS

./bin/create_composite.pl

=head1 DESCRIPTION

Parse un_edifact/trcd to create composite.{txt,dat.*,rev.*}
for further processing in XML::Edifact.pm.

The hash is filled in the following form:

  COMPT{$composite_tag}=
  	"$list_of_codes\t$mand_cond_flags\t".\
  	"$name_space:$cooked_name\t$canon_name";

Codes are seperated by blank, and a "MCCCCCCCC" in NAD is not a
roman number, but related to the codes and has to tell if a
composite or element is mandantory or conditional.

The name is stored twice, once translated ready to use, and once
in the orginal form. A revers index is also build as:

  COMPR{"$name_space:$cooked_name"}=$composite_tag;

This hash is also available as a tab seperated text file, called
composite.txt. A composite.xml can serve as a xml representation of
the trcd contents.

=cut

#------------------------------------------------------------------------------#

use SDBM_File;
use Fcntl;
use XML::Edifact;
use strict;

use vars qw(%COMPT %COMPR);
use vars qw($composite_tag $list_of_codes $mand_cond_flags);
use vars qw($name_space $cooked_name $canon_name);
use vars qw($s $f3 $f5 $f7 $f9);

tie(%COMPT, 'SDBM_File', 'data/composite.dat', O_RDWR|O_CREAT, 0644)	|| die "can not tie composite.tie:".$!;
tie(%COMPR, 'SDBM_File', 'data/composite.rev', O_RDWR|O_CREAT, 0644)	|| die "can not tie composite.num:".$!;

open (INFILE, "un_edifact_d96b/trcd.96b") || die "can not open trcd.96b for reading";
open (TXTFILE, ">data/composite.txt") || die "can not open composite.txt for writing";
open (XMLFILE, ">data/composite.xml") || die "can not open composite.xml for writing";

printf STDERR "reading trcd.96b\n";
print XMLFILE $XML::Edifact::COMPOSITE_SPECIFICATION_HEADER;

while (<INFILE>) {
    chop;	# strip record separator
    if (!($. % 64)) {
	printf STDERR '.';
    }
    $f3 = substr($_,6,4);
    $f5 = substr($_,12,46);
    $f7 = substr($_,59,1);
    $f9 = substr($_,62,7);

    if ($_ =~ '^   [+*#|X -][+*#|X -] [A-Z][0-9][0-9][0-9]  ') {
        flush_composite();
	$composite_tag = $f3;
	$s = " \$", $composite_tag =~ s/$s//;
	$canon_name = $f5;
	$s = '^ *', $canon_name =~ s/$s//;
	$s = " *\$", $canon_name =~ s/$s//;
	$name_space="trcd";
	$cooked_name=XML::Edifact::recode_mark($canon_name);
    }

    if ($_ =~ '^[0-9][0-9][0-9] [+*#|X -] ') {
	$list_of_codes .= $f3." ";
	$mand_cond_flags .= $f7;
    }
}

flush_composite();

close(INFILE);
close(TXTFILE);
close(XMLFILE);
print STDERR "\n";

untie(%COMPT);
untie(%COMPR);

#------------------------------------------------------------------------------#
sub flush_composite() {
    if ($composite_tag ne "") {
    	chop $list_of_codes			 unless $list_of_codes eq "";

	$COMPT{$composite_tag}="$list_of_codes\t$mand_cond_flags\t$name_space:$cooked_name\t$canon_name";
	$COMPR{"$name_space:$cooked_name"}=$composite_tag;
	print TXTFILE "$composite_tag\t$list_of_codes\t$mand_cond_flags\t$name_space:$cooked_name\t$canon_name\n";

	$composite_tag="";
	$list_of_codes="";
	$mand_cond_flags="";
	$name_space="";
	$cooked_name="";
	$canon_name="";
    }
}
#------------------------------------------------------------------------------#
0; 									# exit 0
#------------------------------------------------------------------------------#

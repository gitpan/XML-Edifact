#!/usr/local/bin/perl
# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.3* version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

use XML::Edifact;
use strict;

use vars qw($segm $segmt @segmv);
use vars qw($comp $compt @compv);
use vars qw($elem $elemt @elemv);
use vars qw($code %saw @codes @translated);
use vars qw($s);

use vars qw($debug);

$debug=2;

# -----------------------------------------------------------------------------

print $XML::Edifact::DOCTYPE_HEADER;
 
&XML::Edifact::open_dbm("data");

# -----------------------------------------------------------------------------

@codes       = keys %XML::Edifact::SEGMT;
%saw         = ();
@translated  = ();
@saw{@codes} = ();
@codes = sort keys %saw;
foreach $code (@codes) {
	$segmt=$XML::Edifact::SEGMT{$code};
	@segmv=split('\t', $segmt, 4);
	push @translated, $segmv[2];
}

printf "<!ELEMENT edifact:message (\n\t  %s\n\t)* >\n",
	join("\n\t| ", @translated);
printf "<!ATTLIST edifact:message\n", $codes[0];
printf "\t%s CDATA #IMPLIED\n", "xmlns:edifact";
printf "\t%s CDATA #IMPLIED\n", "xmlns:trsd";
printf "\t%s CDATA #IMPLIED\n", "xmlns:trcd";
printf "\t%s CDATA #IMPLIED\n", "xmlns:tred";
printf "\t%s CDATA #IMPLIED\n", "xmlns:uncl";
printf "\t%s CDATA #IMPLIED\n", "xmlns:anxs";
printf "\t%s CDATA #IMPLIED\n", "xmlns:anxc";
printf "\t%s CDATA #IMPLIED\n", "xmlns:anxe";
printf "\t%s CDATA #IMPLIED\n", "xmlns:unsl";
printf "\t%s CDATA #IMPLIED >\n\n", "xmlns:unknown";

foreach $segm (sort(keys %XML::Edifact::SEGMT)) {
	$segmt=$XML::Edifact::SEGMT{$segm};
	@segmv=split('\t', $segmt, 4);

	printf "\n<!-- Segment: %s %s -->\n", $segm, $segmv[3]	if ($debug >1);

	@codes       = split / /,  " ".$segmv[0];
	%saw         = ();
	@translated  = ();
	@saw{@codes} = ();
	@codes = sort keys %saw;

	foreach $code (@codes) {
		if ($code =~ /^[CS]/) {
			$compt=$XML::Edifact::COMPT{$code};
			@compv=split('\t', $compt, 4);
			push @translated, $compv[2];
		} else {
			$elemt=$XML::Edifact::ELEMT{$code};
			@elemv=split('\t', $elemt, 4);
			push @translated, $elemv[0];
		}
	}

	shift @translated;
	printf "<!ELEMENT %s (\n\t  %s\n\t)* >\n", $segmv[2], 
		join("\n\t| ", @translated);
}

foreach $comp (sort(keys %XML::Edifact::COMPT)) {
	$compt=$XML::Edifact::COMPT{$comp};
	@compv=split('\t', $compt, 4);

	printf "\n<!-- Composite: %s %s -->\n", $comp, $compv[3]	if ($debug >1);

	@codes       = split / /,  " ".$compv[0];
	%saw         = ();
	@translated  = ();
	@saw{@codes} = ();
	@codes = sort keys %saw;

	foreach $code (@codes) {
		$elemt=$XML::Edifact::ELEMT{$code};
		@elemv=split('\t', $elemt, 4);
		push @translated, $elemv[0];
	}

	shift @translated;
	printf "<!ELEMENT %s (\n\t  %s\n\t)* >\n", $compv[2], 
		join("\n\t| ", @translated);
}

foreach $elem (sort(keys %XML::Edifact::ELEMT)) {
	$elemt=$XML::Edifact::ELEMT{$elem};
	@elemv=split('\t', $elemt, 4);
	printf "<!ELEMENT %s (#PCDATA) >\n", $elemv[0];
	if ($XML::Edifact::CODET{$elem."\t"} ne "") {
		@codes = split('\t', $XML::Edifact::CODET{$elem."\t"});
		printf "<!ATTLIST $elemv[0] %s:code CDATA #REQUIRED >\n", $codes[0];
	}
}

# -----------------------------------------------------------------------------

&XML::Edifact::close_dbm;

# -----------------------------------------------------------------------------
0;

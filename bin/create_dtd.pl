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
use strict;

use vars qw($segm $segmt $segmn @segmv $segments);
use vars qw($comp $compt $compn @compv $elements);
use vars qw($code $codet $coden @codev);
use vars qw($debug $i $j $mark $elem %allelem);

$debug=2;

# -----------------------------------------------------------------------------

print <<HERE_IS_HEADER;
<!-- XML DTD for cooked EDI to reflect raw UN/EDIFACT -->
<!-- edicooked02.dtd (c) '98 Kraehe\@Bakunin.North.De -->

<!-- I should warn you that badly written validating XML
     parsers may have problems by running out of memory.

     Its quite large, I know, but it's not yet complete!

     My first attempt on an automatic generated edicooked02.dtd
     failed with massive "content model is ambiguous" errors.
     So I deceided to use a mixed content model to simplify work
     for XML parsers and also for me.

     Goal of Edicooked02.dtd is that any valid EDI message can
     be translated into a valid Edicooked message. The revers
     is NOT true, however! Edicooked does'nt constrain anything
     about segment groups. XML messages are of Edicooked type
     and not of EDI-Invoice to point the difference.
  -->

HERE_IS_HEADER
 
&XML::Edifact::open_dbm("data");
&XML::Edifact::open_num("data");

$segments = "";

foreach $segm (sort(keys %XML::Edifact::SEGMN)) {
	$segmn=$XML::Edifact::SEGMN{$segm};
	$segmt=$XML::Edifact::SEGMT{$segm."\t0"};
	@segmv=split('\t', $segmt, 4);
	$mark =&XML::Edifact::recode_mark($segmv[3]);

	printf "\n<!-- Segment: %s %s -->\n", $segm, $mark	if ($debug >1);

	$segments .= $mark."|\n\t";

	printf "<!ELEMENT %s (", $mark;
	$elements = "";

	for ($i=1; $i<=$segmn; $i++) {
		$segmt=$XML::Edifact::SEGMT{$segm."\t".$i};
		@segmv=split('\t', $segmt, 4);
		if ($segmv[0] =~ /^[CS]/) {
			$comp = $segmv[0];
			$compn=$XML::Edifact::COMPN{$comp};
			
			for ($j=1; $j<=$compn; $j++) {
				$compt=$XML::Edifact::COMPT{$comp."\t".$j};
				@compv=split('\t', $compt, 4);
				$elem = $XML::Edifact::ELEMT{$compv[0]};
				&run_elem($elem,$compv[0]);
			}
		} else {
			$elem =$XML::Edifact::ELEMT{$segmv[0]};
			&run_elem($elem,$segmv[0]);
		}
	}
	chop $elements;
	chop $elements;
	printf "%s", $elements;
	printf "\n\t)* >\n";
}

chop $segments;
chop $segments;
chop $segments;
printf "<!ELEMENT edicooked (\n\t%s)* >\n", $segments;

foreach $code (sort(keys %allelem)) {
	printf "<!-- %s --> ", $code			if ($debug >1);
	if ($XML::Edifact::CODEN{$code} eq "") {
		printf "<!ELEMENT %s (#PCDATA) >\n", $allelem{$code};
	} else {
		printf "<!ELEMENT %s (#PCDATA)* >\n", $allelem{$code};
		printf "              "			if ($debug >1);
		printf "<!ATTLIST %s is CDATA #REQUIRED >\n", $allelem{$code};
	}
}

&XML::Edifact::close_dbm;
&XML::Edifact::close_num;

# -----------------------------------------------------------------------------

sub run_elem {
	my ($elem, $code) = @_;

	$elements .= ("\n\t ".$elem." |") unless ($elements =~ / $elem /);
	$allelem{$code}=$elem;
}

# -----------------------------------------------------------------------------
0;

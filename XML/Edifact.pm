# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.32 version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

package XML::Edifact;

use strict;
use SDBM_File;
use Fcntl;
use XML::Parser;
use Carp;

use vars qw($VERSION $debug $local_url);

$VERSION='0.30';
$local_url='.';					# edit your local url here
$debug=1;					# debug=1 is fine

# ------------------------------------------------------------------------------
# edit the HERE documents for those variables for your systems preferences.
# Ive included both kinds of namespace definitions. You may have to drop one
# if your system is aware about xml namespaces.

use vars qw(
	$MESSAGE_HEADER
	$DOCTYPE_HEADER
	$SEGMENT_SPECIFICATION_HEADER
	$COMPOSITE_SPECIFICATION_HEADER
	);

$MESSAGE_HEADER=<<HERE_MESSAGE_HEADER;
<?xml version="1.0"?>
<!DOCTYPE edifact:message SYSTEM "$local_url/edifact03.dtd">

<!-- XML message produced by edi2xml.pl (c) Kraehe\@Bakunin.North.De -->

<edifact:message
	xmlns:edifact='$local_url/edifact03.rdf' 
	xmlns:trsd='$local_url/edifact03_trsd.rdf'
	xmlns:trcd='$local_url/edifact03_trcd.rdf'
	xmlns:tred='$local_url/edifact03_tred.rdf'
	xmlns:uncl='$local_url/edifact03_uncl.rdf'
	xmlns:anxs='$local_url/edifact03_anxe.rdf'
	xmlns:anxc='$local_url/edifact03_anxc.rdf'
	xmlns:anxe='$local_url/edifact03_anxe.rdf'
	xmlns:unsl='$local_url/edifact03_unsl.rdf'
	xmlns:unknown='$local_url/edifact03_unknown.rdf'
	>
HERE_MESSAGE_HEADER
# ------------------------------------------------------------------------------
$DOCTYPE_HEADER=<<HERE_DOCTYPE_HEADER;
<!-- XML DTD for cooked EDI to reflect raw UN/EDIFACT -->
<!-- edifact03.dtd (c) '98 Kraehe\@Bakunin.North.De -->

<!-- I should warn you that badly written validating XML
     parsers may have problems by running out of memory.

     Its quite large, I know, but it's not yet complete!

     My first attempt on an automatic generated edifact03.dtd
     failed with massive "content model is ambiguous" errors.
     So I deceided to use a mixed content model to simplify work
     for XML parsers and also for me.

     Goal of Edicooked03.dtd is that any wellformed EDI message
     can be translated into a valid Edicooked message.

     The revers is NOT true, however!

     Edicooked does'nt constrain anything about segment groups, and not
     even about the sequence of elements within a segment or composite.

     XML DTDs do not provide the fine granularity for defining
     valid UN/EDIFACT. Use an external checker - write one based
     on top of DOM, and you are granted a virtual Beck's beer.
  -->

HERE_DOCTYPE_HEADER
# ------------------------------------------------------------------------------
$SEGMENT_SPECIFICATION_HEADER=<<HERE_SEGMENT_SPECIFICATION_HEADER;
<?xml version="1.0"?>
<?xml:namespace ns='$local_url/edifact03.dtd'	prefix='edifact' ?>
<!DOCTYPE edifact:segment_specification SYSTEM "edifact03.dtd">
<!-- XML::Edifact segment.xml (c) Kraehe\@Bakunin.North.De -->

<edifact:segment_specifications
	xmlns:edifact='$local_url/edifact03.dtd'
	>
HERE_SEGMENT_SPECIFICATION_HEADER
# ------------------------------------------------------------------------------
$COMPOSITE_SPECIFICATION_HEADER=<<HERE_COMPOSITE_SPECIFICATION_HEADER;
<?xml version="1.0"?>
<?xml:namespace ns='$local_url/edifact03.dtd'	prefix='edifact' ?>
<!DOCTYPE edifact:composite_specification SYSTEM "edifact03.dtd">
<!-- XML::Edifact composite.xml (c) Kraehe\@Bakunin.North.De -->

<edifact:composite_specifications
	xmlns:edifact='$local_url/edifact03.dtd'
	>
HERE_COMPOSITE_SPECIFICATION_HEADER
# ------------------------------------------------------------------------------

use vars qw(%SEGMT %COMPT %CODET %ELEMT);
use vars qw(%SEGMR);

use vars qw($edi_message $xml_message);
use vars qw($advice $advice_component_seperator);
use vars qw($advice_element_seperator $advice_decimal_notation);
use vars qw($advice_release_indicator $advice_segment_terminator);

$xml_message .= "<!-- Hello from XML::EDIFACT -->\n"		if ($debug>1);

# ------------------------------------------------------------------------------

sub open_dbm {
    my ($directory,$fcntl) = @_;

    $fcntl = O_RDWR					unless $fcntl eq "";

    $xml_message .= sprintf "<!-- *** open_dbm -->\n"			if ($debug>1);

    tie(%SEGMT, 'SDBM_File', $directory.'/segment.dat',   $fcntl, 0644)	|| die "can not tie segment.dat:".$!;
    tie(%SEGMR, 'SDBM_File', $directory.'/segment.rev',   $fcntl, 0644)	|| die "can not tie segment.dat:".$!;
    tie(%COMPT, 'SDBM_File', $directory.'/composite.dat', $fcntl, 0644)	|| die "can not tie composite.dat:".$!;
    tie(%ELEMT, 'SDBM_File', $directory.'/element.dat',   $fcntl, 0644)	|| die "can not tie element.dat:".$!;
    tie(%CODET, 'SDBM_File', $directory.'/codes.dat',     $fcntl, 0644)	|| die "can not tie codes.dat:".$!;
}

sub close_dbm {
    untie(%SEGMT);
    untie(%SEGMR);
    untie(%COMPT);
    untie(%ELEMT);
    untie(%CODET);
}

# -----------------------------------------------------------------------------

sub recode_mark {
	my($mark) = @_;
	my($M,$s);

	$M = lc($mark);
	$s = '[^a-z][^a-z]*', $M =~ s/$s/_/g;
#	$s = "_coded\$", $M =~ s/$s//;
	$s = "__*\$", $M =~ s/$s//;
	$s = "^__*", $M =~ s/$s//;
	$s = '__*', $M =~ s/$s/./g;
	return($M);
}

# -----------------------------------------------------------------------------

sub read_edi_message() {
	my($filename) = @_;
	my($size);

	$xml_message .= sprintf "<!-- *** reading message -->\n"		 if ($debug>1);

	$size=(stat($filename))[7]		|| die "cant stat ".$filename;
	die $filename." is to short ".$size." for EDI" 	if ($size <= 9);
	open(F,$filename)			|| die "cant open ".$filename;
	read(F,$edi_message,$size,0)		|| die "cant read message from ".$filename;
	close(F);

	$advice=substr($edi_message,0,9);
	die $filename." is not an EDI message"	if ($advice !~ "^UN[AB]");

	$advice = "UNA:+.? '" unless ($advice =~ "^UNA");

	$advice_component_seperator =substr($advice,3,1);
	$advice_element_seperator   =substr($advice,4,1);
	$advice_decimal_notation    =substr($advice,5,1);
	$advice_release_indicator   =substr($advice,6,1);
	$advice_segment_terminator  =substr($advice,8,1);
}

sub make_xml_message() {

	$xml_message = $MESSAGE_HEADER;

	my($cooked_message,@Segments,$segment,$s);

	$cooked_message  = $edi_message;
	$s = "\\".$advice_release_indicator."\\".$advice_segment_terminator;
	$cooked_message =~ s/$s/\001/g;

	@Segments = split /$advice_segment_terminator/, $cooked_message;
	shift @Segments if ($Segments[0] =~ "^UNA");

	foreach $segment (@Segments) {
		$s = "\\".$advice_segment_terminator;
		$segment =~ s/\001/$s/g;
		&resolve_segment($segment);
	}
	$xml_message .= "</edifact:message>\n";

	return $xml_message;
}

# -----------------------------------------------------------------------------

sub resolve_segment {
	my($raw_segment) = @_;
	my($cooked_segment,@Elements,@Codes,$element,$s,$i);
	my($sg,@sgv);
	my($comment);

	$s="^[ \\n\\r\\t]\$";
	if ($raw_segment !~ /$s/ ) {

		if ($debug) {
			$comment = $raw_segment;
			$comment =~ s/--/__/g;
			$xml_message .= sprintf "<!-- SEGMENT %s -->\n\n", $comment;
		}

		$cooked_segment = $raw_segment;
		$s = "\\".$advice_release_indicator."\\".$advice_element_seperator;
		$cooked_segment =~ s/$s/\001/g;

		$s = "\\".$advice_element_seperator;
		@Elements = split /$s/, $cooked_segment;
		@sgv = split("\t", $SEGMT{$Elements[0]}, 4);
		@Codes    = split / /,  " ".$sgv[0];

		$xml_message .= sprintf "<!-- *** name %s %s -->\n", $Elements[0], $sgv[3]	if ($debug>2);
		if (($sgv[2] ne '') && ($#Codes>=$#Elements)) {
			$xml_message .= sprintf "  <%s>\n", $sgv[2];

			for ($i = 1; $i <= $#Elements; $i++) {
				$element  = $Elements[$i];
				$element =~ s/\001/$advice_element_seperator/g;

				if ($Elements[$i] ne '') {
					# resolve_element
					$xml_message .= sprintf "<!-- *** %s='%s' -->\n", $Codes[$i],$Elements[$i] if ($debug>1);
					resolve_element($Codes[$i], $Elements[$i]);
				}
			}
			$xml_message .= sprintf "  </%s>\n\n", $sgv[2];
		} else {
			$xml_message .= sprintf "  <edifact:raw_segment data=\"%s\"/>\n", $raw_segment;
		}
	}
}

# -----------------------------------------------------------------------------

sub resolve_element {
	my($code, $raw_element) = @_;
	my($cooked_element,@Components,@Codes,$component,$s,$i);
	my($cm,@cmv);
	my($ok);

	$ok=0;

	$xml_message .= sprintf "<!-- *** resolve element %s %s -->\n", $code, $raw_element if ($debug>1);

	$cooked_element = $raw_element;
	$s = "\\".$advice_release_indicator."\\".$advice_component_seperator;
	$cooked_element =~ s/$s/\001/g;

	if (($code =~ /^[CS]/) && (($cm = $COMPT{$code}) ne '')) {

		@cmv = split("\t", $cm, 4);

		$xml_message .= sprintf "    <%s>\n", $cmv[2]			if ($cmv[2]);

		$s = "\\".$advice_component_seperator;
		@Components = split /$s/, $cooked_element;
		@Codes = split / /, $cmv[0];

		foreach $i (0 .. $#Components) {
			$component = $Components[$i];
			if ($component ne '') {
				$s = $advice_component_seperator;
				$component =~ s/\001/$s/g;
				&resolve_code($Codes[$i], $component);
			}
		}

		$xml_message .= sprintf "    </%s>\n", $cmv[2]			if ($cmv[2]);
		$ok=1;
	}
	if (($code =~ "^[0-9]") && ($cm = $ELEMT{$code})) {
		$s = $advice_component_seperator;
		$cooked_element =~ s/\001/$s/g;
		&resolve_code($code, $cooked_element);
		$ok=1;
	}
	$xml_message .= sprintf "  <edifact:raw_element data=\"%s\"/>\n", $raw_element unless $ok;
}

# -----------------------------------------------------------------------------

sub resolve_code {
	my($code, $val) = @_;
	my($cd,$mark,@cdv);

	$mark=$ELEMT{$code};
	$xml_message .= sprintf "<!-- *** resolve code %s %s -->\n", $code, $val if ($debug>1);

	if ($CODET{$code."\t"} ne "") {
		$cd = $CODET{$code."\t".$val};
		if ($cd ne '') {
			@cdv=split /\t/, $cd;
			$xml_message .= sprintf "      <%s %s:code=\"%s:%s\">%s</%s>\n", $mark, $cdv[0], $code, $val, $cdv[1], $mark;
		}
		else {
			$xml_message .= sprintf "      <%s unknown:code=\"%s:%s\">%s</%s>\n", $mark, $code, $val, $val, $mark;
		}
	}
	else {
		$xml_message .= sprintf "      <%s>%s</%s>\n", $mark, $val, $mark;
	}
}

# -----------------------------------------------------------------------------

sub read_xml_message() {
	my($filename) = @_;
	my($size);

	$size=(stat($filename))[7]		|| die "cant stat ".$filename;
	die $filename." is to short ".$size." for EDI" 	if ($size <= 9);
	open(F,$filename)			|| die "cant open ".$filename;
	read(F,$xml_message,$size,0)		|| die "cant read message from ".$filename;
	close(F);

	$advice_component_seperator = ":";
	$advice_element_seperator   = "+";
	$advice_decimal_notation    = ".";
	$advice_release_indicator   = "?";
	$advice_segment_terminator  = "'";
}

use vars qw(@edi_segment @edi_group $edi_valid $edi_level $edi_si $edi_gi);

sub make_edi_message() {
	my $xml_parser;

	$edi_message = "UNA";
	$edi_message .= $advice_component_seperator;
	$edi_message .= $advice_element_seperator;
	$edi_message .= $advice_decimal_notation;
	$edi_message .= $advice_release_indicator;
	$edi_message .= " ";
	$edi_message .= $advice_segment_terminator;

	$edi_level    = 0;

	$xml_parser   = new XML::Parser(Handlers => {	Start => \&handle_start,
							End   => \&handle_end,
							Char  => \&handle_char});
	$xml_parser -> parse($xml_message);

	return $edi_message;
}

sub handle_start {
	my $expat   = shift @_;
	my $element = shift @_;
	my %options = @_;
	my ($opt,$val,$i);
	my (@sgv,@cmv,@sgc,@cmc,$junk,$trans);

	if ($debug>1) {
		printf STDERR "(%s\n", $element;
		foreach $opt (keys (%options)) {
			printf STDERR "A%s=%s\n", $opt, $options{$opt};
		}
	}

	if ($edi_level == 0) {
		die "this is not XML::Edifact" if ($element !~ /^[^:]*:message/);
	}
	if ($edi_level == 1) {
		if ($element =~ /^[^:]*:raw_segment/) {
			foreach $opt (keys (%options)) {
				if ($opt eq "data") {
					$edi_message .= $options{$opt};
					$edi_message .= $advice_segment_terminator;
				}
			}
			@edi_segment = ();
			$edi_si      = 0;
			@edi_group   = ();
			$edi_gi      = 0;
			$edi_valid   = 1;
		} else {
			@edi_segment = ($SEGMR{$element});
			$edi_si      = 0;
			@edi_group   = ();
			$edi_gi      = 0;
			$edi_valid   = ($edi_segment[0] ne "");
		}
	}
	if ($edi_valid) {
	    if ($edi_level == 2) {
		$edi_si++;
		@edi_group   = ();
		$edi_gi      = 0;

		@sgv = split("\t", $SEGMT{$edi_segment[0]}, 4);
		@sgc = split / /,  " ".$sgv[0];

		SKIP_SEGMT: for ($i = $edi_si; $i <= $#sgc; $i++) {
			if ($sgc[$i] =~ /^[A-Z]/) {
				($junk, $junk, $trans, $junk) = split /\t/, $COMPT{$sgc[$i]};
			} else {
				$trans =$ELEMT{$sgc[$i]};
			}
			last SKIP_SEGMT if ($trans eq $element);
		}

		if ($i <= $#sgc) {
			$edi_si = $i;
		} else {
			$edi_valid = 0;
		}

		foreach $opt (keys (%options)) {
			if ($opt =~ "^[^:]*:code") {
				$val = $options{$opt};
				$val =~ s/^[^:]*://;
				$edi_group[$edi_gi] = $val;
			}
		}
	    }
	    if ($edi_level == 3) {
		@sgv = split("\t", $SEGMT{$edi_segment[0]}, 4);
		@sgc = split / /,  " ".$sgv[0];
		@cmv = split("\t", $COMPT{$sgc[$edi_si]}, 4);
		@cmc = split / /,  $cmv[0];

		SKIP_COMPT: for ($i = $edi_gi; $i <= $#cmc; $i++) {
			$trans =$ELEMT{$cmc[$i]};
			last SKIP_COMPT if ($trans eq $element);
		}

		if ($i <= $#cmc) {
			$edi_gi = $i;
		} else {
			$edi_valid = 0;
		}

		foreach $opt (keys (%options)) {
			if ($opt =~ "^[^:]*:code") {
				$val = $options{$opt};
				$val =~ s/^[^:]*://;
				$edi_group[$edi_gi] = $val;
			}
		}
	    }
	}
	$edi_level++;
}

sub handle_end {
	my ($expat, $element) = @_;
	my ($i,$cooked,$si,$s1,$s2);

	if ($debug>1) {
		printf STDERR ")%s\n", $element;
	}

	$edi_level--;

	if ($edi_valid) {
	    if ($edi_level == 1) {
	    	if ($#edi_segment>0) {
			$edi_message .= join $advice_element_seperator, @edi_segment;
			$edi_message .= $advice_segment_terminator;
		}
	    }
	    if ($edi_level == 2) {
		for ($i = 0; $i<= $#edi_group; $i++) {
			$cooked = $edi_group[$i];

			foreach $si ($advice_release_indicator, $advice_component_seperator, $advice_element_seperator, $advice_segment_terminator) {
				$s1 = "\\".$si;
				$s2 = $advice_release_indicator.$si;
				$cooked =~ s/$s1/$s2/g;
			}

			$edi_group[$i] = $cooked;
		}
		$edi_segment[$edi_si] .= join $advice_component_seperator, @edi_group;
	    }
	    if ($edi_level == 3) {
		$edi_gi++;
	    }
	} else {
	    carp "invalid message";
	}
}

sub handle_char {
	my ($expat, $element) = @_;


	if ($element !~ /^[\n\r\t ]*$/) {
		if ($debug>1) {
			printf STDERR "-%s\n", $element;
		}
		$element =~ s/[\n\r\t ]*$//;
		$element =~ s/^[\n\r\t ]*//;

		$edi_group[$edi_gi] = $element if $edi_group[$edi_gi] eq "";
	}
}

# ------------------------------------------------------------------------------
1;           					# modules must return true
# ------------------------------------------------------------------------------
__END__

=head1 NAME

XML::Edifact - Perl module to handle XML::Edifact messages.

=head1 SYNOPSIS

use	XML::Edifact;

	&XML::Edifact::open_dbm("data");
	&XML::Edifact::read_edi_message($ARGV[0]);
print	&XML::Edifact::make_xml_message();
	&XML::Edifact::close_dbm();
0;

---------------------------------------------------------------

use	XML::Edifact;

	&XML::Edifact::open_dbm("data");
	&XML::Edifact::read_xml_message($ARGV[0]);
print	&XML::Edifact::make_edi_message();
	&XML::Edifact::close_dbm();
0;

=head1 DESCRIPTION

XML-Edifact started as Onyx-EDI which was a gawk script.
XML::Edifact-0.30 still shows its bad anchesor called a2p
in some parts.

The current module is just able to open and close the SDBM
files found in the directory pointed by open_dbm. Read a
EDIFACT message into a buffer global to the package, and
to print this message as XML on STDOUT.

The best think you can currently do with it:
  Run the regession test found under Installation in
  the README file, using you own files.

The second best: Just view the files in ./examples with
your favourite pager. Anything that can be found after
regression test, can also be found in this directory.

If you have other EDIFACT files, I would like to include
them into the next version. I'm also open to any comments,
as told "anything is still in flux" !

=head1 AUTHOR

Michael Koehne, Kraehe@Bakunin.North.De

=head1 SEE ALSO

perl(1), XML::Parser(3), UN/EDIFACT Draft.

=cut

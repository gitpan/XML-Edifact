# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.30 version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

package XML::Edifact;

use strict;
use vars qw($VERSION $debug $local_url);

$VERSION='0.30';
$local_url='.';					# edit your local url here
$debug=1;					# debug=1 is fine

# edit the HERE documents for those variables for your systems preferences.
# Ive included both kinds of namespace definitions. You may have to drop one
# if your system is aware about xml namespaces.

use vars qw(
	$MESSAGE_HEADER
	$DOCTYPE_HEADER
	$SEGMENT_SPECIFICATION_HEADER
	$COMPOSITE_SPECIFICATION_HEADER
	);

# ------------------------------------------------------------------------------
$MESSAGE_HEADER=<<HERE_MESSAGE_HEADER;
<?xml version="1.0"?>

<?xml:namespace ns='$local_url/edicooked03.rdf'		prefix='edicooked' ?>
<?xml:namespace ns='$local_url/edicooked03_trsd.rdf'	prefix='trsd' ?>
<?xml:namespace ns='$local_url/edicooked03_trcd.rdf'	prefix='trcd' ?>
<?xml:namespace ns='$local_url/edicooked03_tred.rdf'	prefix='tred' ?>
<?xml:namespace ns='$local_url/edicooked03_uncl.rdf'	prefix='uncl' ?>
<?xml:namespace ns='$local_url/edicooked03_anxs.rdf'	prefix='anxs' ?>
<?xml:namespace ns='$local_url/edicooked03_anxc.rdf'	prefix='anxc' ?>
<?xml:namespace ns='$local_url/edicooked03_anxe.rdf'	prefix='anxe' ?>
<?xml:namespace ns='$local_url/edicooked03_unsl.rdf'	prefix='unsl' ?>
<?xml:namespace ns='$local_url/edicooked03_unknown.rdf'	prefix='unknown' ?>

<!DOCTYPE edicooked:message SYSTEM "$local_url/edicooked03.dtd">

<!-- XML message produced by edi2xml.pl (c) Kraehe\@Bakunin.North.De -->

<edicooked:message
	xmlns:edicooked='$local_url/edicooked03.rdf' 
	xmlns:trsd='$local_url/edicooked03_trsd.rdf'
	xmlns:trcd='$local_url/edicooked03_trcd.rdf'
	xmlns:tred='$local_url/edicooked03_tred.rdf'
	xmlns:uncl='$local_url/edicooked03_uncl.rdf'
	xmlns:anxs='$local_url/edicooked03_anxe.rdf'
	xmlns:anxc='$local_url/edicooked03_anxc.rdf'
	xmlns:anxe='$local_url/edicooked03_anxe.rdf'
	xmlns:unsl='$local_url/edicooked03_unsl.rdf'
	xmlns:unknown='$local_url/edicooked03_unknown.rdf'
	>
HERE_MESSAGE_HEADER
# ------------------------------------------------------------------------------
$DOCTYPE_HEADER=<<HERE_DOCTYPE_HEADER;
<!-- XML DTD for cooked EDI to reflect raw UN/EDIFACT -->
<!-- edicooked03.dtd (c) '98 Kraehe\@Bakunin.North.De -->

<!-- I should warn you that badly written validating XML
     parsers may have problems by running out of memory.

     Its quite large, I know, but it's not yet complete!

     My first attempt on an automatic generated edicooked03.dtd
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
<?xml:namespace ns='$local_url/edicooked03.dtd'	prefix='edicooked' ?>
<!DOCTYPE edicooked:segment_specification SYSTEM "edicooked03.dtd">
<!-- XML::Edifact segment.xml (c) Kraehe\@Bakunin.North.De -->

<edicooked:segment_specifications
	xmlns:edicooked='$local_url/edicooked03.dtd'
	>
HERE_SEGMENT_SPECIFICATION_HEADER
# ------------------------------------------------------------------------------
$COMPOSITE_SPECIFICATION_HEADER=<<HERE_COMPOSITE_SPECIFICATION_HEADER;
<?xml version="1.0"?>
<?xml:namespace ns='$local_url/edicooked03.dtd'	prefix='edicooked' ?>
<!DOCTYPE edicooked:composite_specification SYSTEM "edicooked03.dtd">
<!-- XML::Edifact composite.xml (c) Kraehe\@Bakunin.North.De -->

<edicooked:composite_specifications
	xmlns:edicooked='$local_url/edicooked03.dtd'
	>
HERE_COMPOSITE_SPECIFICATION_HEADER
# ------------------------------------------------------------------------------

use vars qw(%SEGMT %COMPT %CODET %ELEMT);
use vars qw(%SEGMR %COMPR %CODER %ELEMR);

use vars qw($raw_message $advice $advice_component_seperator);
use vars qw($advice_element_seperator $advice_decimal_notation);
use vars qw($advice_release_indicator $advice_segment_terminator);

use SDBM_File;
use Fcntl;

print "<!-- Hello from XML::EDIFACT -->\n"		if ($debug>1);

# ------------------------------------------------------------------------------

sub open_dbm {
    my ($directory,$fcntl) = @_;

    $fcntl = O_RDWR					unless $fcntl eq "";

    printf "<!-- *** open_dbm -->\n"			if ($debug>1);

    tie(%SEGMT, 'SDBM_File', $directory.'/segment.dat',   $fcntl, 0644)	|| die "can not tie segment.dat:".$!;
    tie(%SEGMR, 'SDBM_File', $directory.'/segment.rev',   $fcntl, 0644)	|| die "can not tie segment.dat:".$!;
    tie(%COMPT, 'SDBM_File', $directory.'/composite.dat', $fcntl, 0644)	|| die "can not tie composite.dat:".$!;
    tie(%COMPR, 'SDBM_File', $directory.'/composite.rev', $fcntl, 0644)	|| die "can not tie composite.dat:".$!;
    tie(%ELEMT, 'SDBM_File', $directory.'/element.dat',   $fcntl, 0644)	|| die "can not tie element.dat:".$!;
    tie(%ELEMR, 'SDBM_File', $directory.'/element.rev',   $fcntl, 0644)	|| die "can not tie element.dat:".$!;
    tie(%CODET, 'SDBM_File', $directory.'/codes.dat',     $fcntl, 0644)	|| die "can not tie codes.dat:".$!;
}

sub close_dbm {
    untie(%SEGMT);
    untie(%SEGMR);
    untie(%COMPT);
    untie(%COMPR);
    untie(%ELEMT);
    untie(%ELEMR);
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

sub read_message() {
	my($filename) = @_;
	my($size);

	printf "<!-- *** reading message -->\n"		 if ($debug>1);

	$size=(stat($filename))[7]		|| die "cant stat ".$filename;
	die $filename." is to short ".$size." for EDI" 	if ($size <= 9);
	open(F,$filename)			|| die "cant open ".$filename;
	read(F,$raw_message,$size,0)		|| die "cant read message from ".$filename;
	close(F);

	$advice=substr($raw_message,0,9);
	die $filename." is not an EDI message"	if ($advice !~ "^UNA");

	$advice_component_seperator =substr($advice,3,1);
	$advice_element_seperator   =substr($advice,4,1);
	$advice_decimal_notation    =substr($advice,5,1);
	$advice_release_indicator   =substr($advice,6,1);
	$advice_segment_terminator  =substr($advice,8,1);
}

sub process_message() {

	print $MESSAGE_HEADER;

	my($cooked_message,@Segments,$segment,$s);

	$cooked_message  = $raw_message;
	$s = "\\".$advice_release_indicator."\\".$advice_segment_terminator;
	$cooked_message =~ s/$s/\001/g;

	@Segments = split /$advice_segment_terminator/, $cooked_message;
	shift @Segments;

	foreach $segment (@Segments) {
		$s = "\\".$advice_segment_terminator;
		$segment =~ s/\001/$s/g;
		&resolve_segment($segment);
	}
	print "</edicooked:message>\n";
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
			printf "<!-- SEGMENT %s -->\n\n", $comment;
		}

		$cooked_segment = $raw_segment;
		$s = "\\".$advice_release_indicator."\\".$advice_element_seperator;
		$cooked_segment =~ s/$s/\001/g;

		$s = "\\".$advice_element_seperator;
		@Elements = split /$s/, $cooked_segment;
		@sgv = split("\t", $SEGMT{$Elements[0]}, 4);
		@Codes    = split / /,  " ".$sgv[0];

		printf "<!-- *** name %s %s -->\n", $Elements[0], $sgv[3]	if ($debug>2);
		if (($sgv[2] ne '') && ($#Codes>=$#Elements)) {
			printf "  <%s>\n", $sgv[2];

			for ($i = 1; $i <= $#Elements; $i++) {
				$element  = $Elements[$i];
				$element =~ s/\001/$advice_element_seperator/g;

				if ($Elements[$i] ne '') {
					# resolve_element
					printf "<!-- *** %s='%s' -->\n", $Codes[$i],$Elements[$i] if ($debug>1);
					resolve_element($Codes[$i], $Elements[$i]);
				}
			}
			printf "  </%s>\n\n", $sgv[2];
		} else {
			printf "  <edicooked:raw_segment data=\"%s\"/>\n", $raw_segment;
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

	printf "<!-- *** resolve element %s %s -->\n", $code, $raw_element if ($debug>1);

	$cooked_element = $raw_element;
	$s = "\\".$advice_release_indicator."\\".$advice_component_seperator;
	$cooked_element =~ s/$s/\001/g;

	if (($code =~ /^[CS]/) && (($cm = $COMPT{$code}) ne '')) {

		@cmv = split("\t", $cm, 4);

		printf "    <%s>\n", $cmv[2]			if ($cmv[2]);

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

		printf "    </%s>\n", $cmv[2]			if ($cmv[2]);
		$ok=1;
	}
	if (($code =~ "^[0-9]") && ($cm = $ELEMT{$code})) {
		$s = $advice_component_seperator;
		$cooked_element =~ s/\001/$s/g;
		&resolve_code($code, $cooked_element);
		$ok=1;
	}
	printf "  <edicooked:raw_element data=\"%s\"/>\n", $raw_element unless $ok;
}

# -----------------------------------------------------------------------------

sub resolve_code {
	my($code, $val) = @_;
	my($cd,$mark,@cdv);

	$mark=$ELEMT{$code};
	printf "<!-- *** resolve code %s %s -->\n", $code, $val if ($debug>1);

	if ($CODET{$code."\t"} ne "") {
		$cd = $CODET{$code."\t".$val};
		if ($cd ne '') {
			@cdv=split /\t/, $cd;
			printf "      <%s %s:code=\"%s:%s\">%s</%s>\n", $mark, $cdv[0], $code, $val, $cdv[1], $mark;
		}
		else {
			printf "      <%s unknown:code=\"%s:%s\">%s</%s>\n", $mark, $code, $val, $val, $mark;
		}
	}
	else {
		printf "      <%s>%s</%s>\n", $mark, $val, $mark;
	}
}

# ------------------------------------------------------------------------------
1;           					# modules must return true
# ------------------------------------------------------------------------------
__END__

=head1 NAME

XML::Edifact - Perl module to handle XML::Edifact messages.

=head1 SYNOPSIS

use XML::Edifact;

&XML::Edifact::open_dbm("data");
&XML::Edifact::read_message($ARGV[0]);
&XML::Edifact::process_message();
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
  Run the regession test found in ./bin/make_test.sh

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

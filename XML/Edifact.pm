# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.3x version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

package XML::Edifact;

use strict;
use XML::Edifact::Config;
use SDBM_File;
use Fcntl;
use XML::Parser;
use Carp;

use vars qw($VERSION $debug);

$VERSION='0.33';
$debug=1;					# debug=1 is fine

# ------------------------------------------------------------------------------
# edit the HERE documents for those variables for your systems preferences.
# Ive included both kinds of namespace definitions. You may have to drop one
# if your system is aware about xml namespaces.

sub eval_xml_edifact_headers {
use vars qw(
	$MESSAGE_HEADER
	$DOCTYPE_HEADER
	$SEGMENT_SPECIFICATION_HEADER
	$COMPOSITE_SPECIFICATION_HEADER
	);

$MESSAGE_HEADER=<<HERE_MESSAGE_HEADER;
<?xml version="1.0"?>
<!DOCTYPE edifact:message SYSTEM "$XML::Edifact::Config::URL/edifact03.dtd">
<!-- XML message produced by edi2xml.pl (c) Kraehe\@Bakunin.North.De -->
<edifact:message
	xmlns:edifact='$XML::Edifact::Config::URL/edifact03.rdf'
	xmlns:trsd='$XML::Edifact::Config::URL/edifact03_trsd.rdf'
	xmlns:trcd='$XML::Edifact::Config::URL/edifact03_trcd.rdf'
	xmlns:tred='$XML::Edifact::Config::URL/edifact03_tred.rdf'
	xmlns:uncl='$XML::Edifact::Config::URL/edifact03_uncl.rdf'
	xmlns:anxs='$XML::Edifact::Config::URL/edifact03_anxe.rdf'
	xmlns:anxc='$XML::Edifact::Config::URL/edifact03_anxc.rdf'
	xmlns:anxe='$XML::Edifact::Config::URL/edifact03_anxe.rdf'
	xmlns:unsl='$XML::Edifact::Config::URL/edifact03_unsl.rdf'
	xmlns:unknown='$XML::Edifact::Config::URL/edifact03_unknown.rdf'
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
<?xml:namespace ns='$XML::Edifact::Config::URL/edifact03.dtd'	prefix='edifact' ?>
<!DOCTYPE edifact:segment_specification SYSTEM "edifact03.dtd">
<!-- XML::Edifact segment.xml (c) Kraehe\@Bakunin.North.De -->

<edifact:segment_specifications
	xmlns:edifact='$XML::Edifact::Config::URL/edifact03.dtd'
	>
HERE_SEGMENT_SPECIFICATION_HEADER
# ------------------------------------------------------------------------------
$COMPOSITE_SPECIFICATION_HEADER=<<HERE_COMPOSITE_SPECIFICATION_HEADER;
<?xml version="1.0"?>
<?xml:namespace ns='$XML::Edifact::Config::URL/edifact03.dtd'	prefix='edifact' ?>
<!DOCTYPE edifact:composite_specification SYSTEM "edifact03.dtd">
<!-- XML::Edifact composite.xml (c) Kraehe\@Bakunin.North.De -->

<edifact:composite_specifications
	xmlns:edifact='$XML::Edifact::Config::URL/edifact03.dtd'
	>
HERE_COMPOSITE_SPECIFICATION_HEADER
}
# end of sub eval_xml_edifact_headers
# ------------------------------------------------------------------------------

use vars qw(%SEGMT %COMPT %CODET %ELEMT);
use vars qw(%SEGMR);

use vars qw($edi_message $xml_message @xml_msg);
use vars qw($advice $advice_component_seperator);
use vars qw($advice_element_seperator $advice_decimal_notation);
use vars qw($advice_release_indicator $advice_segment_terminator);
use vars qw($indent_join $indent_tab);

# ------------------------------------------------------------------------------

sub open_dbm {
    my ($directory,$fcntl) = @_;

    $directory = $XML::Edifact::Config::DAT unless $directory;
    $fcntl     = O_RDONLY                   unless $fcntl;

    tie(%SEGMT, 'SDBM_File', $directory.'/segment.dat',   $fcntl, 0644)	|| die "can not tie segment.dat:".$!;
    tie(%SEGMR, 'SDBM_File', $directory.'/segment.rev',   $fcntl, 0644)	|| die "can not tie segment.dat:".$!;
    tie(%COMPT, 'SDBM_File', $directory.'/composite.dat', $fcntl, 0644)	|| die "can not tie composite.dat:".$!;
    tie(%ELEMT, 'SDBM_File', $directory.'/element.dat',   $fcntl, 0644)	|| die "can not tie element.dat:".$!;
    tie(%CODET, 'SDBM_File', $directory.'/codes.dat',     $fcntl, 0644)	|| die "can not tie codes.dat:".$!;

    $indent_join='';
    $indent_tab='';
    eval_xml_edifact_headers();
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

sub read_edi_message {
	my($filename) = @_;
	my($size);

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

use vars qw($cooked_element_substitute $cooked_message_substitute);
use vars qw($cooked_segment_substitute $component_split $element_split);

sub make_xml_message {
	@xml_msg = ();
	push @xml_msg, $MESSAGE_HEADER;
	$xml_msg[0] =~ s!\n!!g		unless $indent_join;
	$xml_msg[0] =~ s!\t! !g		unless $indent_tab;

	my($cooked_message,@Segments,$segment,$s);

	$cooked_message_substitute = "\\".$advice_release_indicator."\\".$advice_segment_terminator;
	$cooked_segment_substitute = "\\".$advice_release_indicator."\\".$advice_element_seperator;
	$element_split             = "\\".$advice_element_seperator;
	$cooked_element_substitute = "\\".$advice_release_indicator."\\".$advice_component_seperator;
	$component_split           = "\\".$advice_component_seperator;

	$cooked_message = $edi_message;
	$cooked_message =~ s/$cooked_message_substitute/\001/g;

	@Segments = split /$advice_segment_terminator/, $cooked_message;
	shift @Segments if ($Segments[0] =~ "^UNA");

	foreach $segment (@Segments) {
		$segment =~ s/\001/$advice_segment_terminator/g;
		resolve_segment($segment);
	}
	push @xml_msg , "</edifact:message>";

	resolve_tabs() if $indent_tab;
	$xml_message = (join $indent_join,@xml_msg).$indent_join;
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
			push @xml_msg, '<!-- SEGMENT '.$comment.' -->';
		}

		$cooked_segment = $raw_segment;
		$cooked_segment =~ s/$cooked_segment_substitute/\001/g;

		@Elements = split /$element_split/, $cooked_segment;
		@sgv      = split "\t", $SEGMT{$Elements[0]}, 4;
		@Codes    = split / /,  " ".$sgv[0];

		push @xml_msg, '<!-- *** name '.$Elements[0].' '.$sgv[3].' -->'	if ($debug>2);
		if (($sgv[2] ne '') && ($#Codes>=$#Elements)) {
			push @xml_msg, '<'.$sgv[2].'>';

			foreach $i (1 .. $#Elements) {
				$element  = $Elements[$i];
				$element =~ s/\001/$advice_element_seperator/g;

				if ($Elements[$i] ne '') {
					# resolve_element
					push @xml_msg, '<!-- *** '.$Codes[$i].'='.$Elements[$i].' -->' if ($debug>1);
					resolve_element($Codes[$i], $Elements[$i]);
				}
			}
			push @xml_msg, '</'.$sgv[2].'>';
		} else {
			push @xml_msg, '<edifact:raw_segment data="'.$raw_segment.'"/>';
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

	push @xml_msg, '<!-- *** resolve element '.$code.' '.$raw_element.' -->' if ($debug>1);

	$cooked_element = $raw_element;
	$cooked_element =~ s/$cooked_element_substitute/\001/g;

	if (($code =~ /^[CS]/) && ($cm = $COMPT{$code})) {

		@cmv = split("\t", $cm, 4);

		push @xml_msg, '<'.$cmv[2].'>'			if ($cmv[2]);

		@Components = split /$component_split/, $cooked_element;
		@Codes = split / /, $cmv[0];

		foreach $i (0 .. $#Components) {
			$component = $Components[$i];
			if ($component ne '') {
				$component =~ s/\001/$advice_component_seperator/g;
				resolve_code($Codes[$i], $component);
			}
		}

		push @xml_msg, '</'.$cmv[2].'>'			if ($cmv[2]);
		$ok=1;
	}
	if (($code =~ "^[0-9]") && ($cm = $ELEMT{$code})) {
		$cooked_element =~ s/\001/$advice_component_seperator/g;
		resolve_code($code, $cooked_element);
		$ok=1;
	}
	push @xml_msg, '<edifact:raw_element data="'.$raw_element.'"/>' unless $ok;
}

# -----------------------------------------------------------------------------

sub encode_xml {
	my ($val) = @_;

	$val =~ s/&/\&amp;/g;
	$val =~ s/</\&lt;/g;

	return $val;
}

sub resolve_code {
	my ($code, $val) = @_;
	my ($cd,@cdv,$enc);

	my ($mark,$coded) = split / /, $ELEMT{$code};

	push @xml_msg, '<!-- *** resolve code '.$code.' '.$val.' -->' if ($debug>1);

	if ($coded) {
		$cd = $CODET{$code."\t".$val};
		if ($cd ne '') {
			@cdv=split /\t/, $cd;
			push @xml_msg, '<'.$mark.' '.$cdv[0].':code="'.$code.':'.encode_xml($val).'">'.encode_xml($cdv[1]).'</'.$mark.'>';
		}
		else {
			$enc = encode_xml($val);
			push @xml_msg, '<'.$mark.    ' unknown:code="'.$code.':'.$enc.'">'.$enc.   '</'.$mark.'>';
		}
	}
	else {
		push @xml_msg, '<'.$mark.'>'.encode_xml($val).'</'.$mark.'>';
	}
}

# -----------------------------------------------------------------------------

sub resolve_tabs {
	my ($i,$v,$d);

	$d = 0;
	foreach $i (0 .. $#xml_msg) {
		$v=$xml_msg[$i];
		$v =~ s/^[ \t]+//;
		$d--	if (($v =~ m!^</!) && ($d>0));
		$xml_msg[$i] = $indent_tab x $d . $v;
		$d++	if (($v =~ m!^<[a-z]!) && ($v !~ m!</!) && ($v !~ m!/>!));
	}
}

# -----------------------------------------------------------------------------

sub read_xml_message {
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

sub make_edi_message {
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
	my (@sgv,@cmv,@sgc,@cmc,$junk,$trans,$coded);

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
				($trans,$coded) =split / /, $ELEMT{$sgc[$i]}, 2;
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
			($trans,$coded) =split / /, $ELEMT{$cmc[$i]}, 2;
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
	    carp "invalid xml-edifact at $edi_level level $element";
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
XML::Edifact-0.3x still shows its bad anchesor called a2p
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

# 
# Copyright (c) 1998 Michael Koehne <kraehe@copyleft.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.

package XML::Edifact;

use 5.006;
no warnings 'utf8' ;

use strict;
use XML::Edifact::Config;
use SDBM_File;
use Fcntl;
use XML::Parser;
use Carp;

use vars qw($VERSION $debug);

$VERSION='0.43';
$debug=1;					# debug=1 is fine

# ------------------------------------------------------------------------------
# edit the HERE documents for those variables for your systems preferences.

use vars qw(
	$MESSAGE_NAMESPACE
	$MESSAGE_HEADER
	);

sub eval_xml_edifact_headers {
	$MESSAGE_NAMESPACE = "edifact" unless $MESSAGE_NAMESPACE;

	$MESSAGE_HEADER=<<HERE_MESSAGE_HEADER;
		<?xml version="1.0"?>
		<!-- XML message produced by edi2xml.pl (c) Kraehe\@Copyleft.de -->
		<$MESSAGE_NAMESPACE:message
		  xmlns:$MESSAGE_NAMESPACE='$XML::Edifact::Config::URL/LIB/xml-edifact-03/$MESSAGE_NAMESPACE.rdf'
		  xmlns:trsd='$XML::Edifact::Config::URL/LIB/xml-edifact-03/trsd.rdf'
		  xmlns:trcd='$XML::Edifact::Config::URL/LIB/xml-edifact-03/trcd.rdf'
		  xmlns:tred='$XML::Edifact::Config::URL/LIB/xml-edifact-03/tred.rdf'
		  xmlns:uncl='$XML::Edifact::Config::URL/LIB/xml-edifact-03/uncl.rdf'
		  xmlns:anxs='$XML::Edifact::Config::URL/LIB/xml-edifact-03/anxs.rdf'
		  xmlns:anxc='$XML::Edifact::Config::URL/LIB/xml-edifact-03/anxc.rdf'
		  xmlns:anxe='$XML::Edifact::Config::URL/LIB/xml-edifact-03/anxe.rdf'
		  xmlns:unsl='$XML::Edifact::Config::URL/LIB/xml-edifact-03/unsl.rdf'
		  xmlns:unknown='$XML::Edifact::Config::URL/LIB/xml-edifact-03/unknown.rdf' >
HERE_MESSAGE_HEADER
	$MESSAGE_HEADER =~ s/^\t\t//;
	$MESSAGE_HEADER =~ s/\n\t\t/\n/g;
}

# end of sub eval_xml_edifact_headers
# ------------------------------------------------------------------------------

use vars qw(%SEGMT %COMPT %CODET %ELEMT);
use vars qw(%SEGMR %EXTEND);

use vars qw($edi_message $xml_message @xml_msg);
use vars qw($advice $advice_component_seperator);
use vars qw($advice_element_seperator $advice_decimal_notation);
use vars qw($advice_release_indicator $advice_segment_terminator);
use vars qw($indent_join $indent_tab);
use vars qw($patch_segment $patch_composite $last_segment $last_composite);

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
	die $filename." is not an EDI message"	if ($advice !~ "^UN[A-Z]");

	$advice = "UNA:+.? '" unless ($advice =~ "^UNA");

	$advice_component_seperator =substr($advice,3,1);
	$advice_element_seperator   =substr($advice,4,1);
	$advice_decimal_notation    =substr($advice,5,1);
	$advice_release_indicator   =substr($advice,6,1);
	$advice_segment_terminator  =substr($advice,8,1);
}

use vars qw($cooked_element_substitute $cooked_release_substitute);
use vars qw($cooked_message_substitute $cooked_segment_substitute);
use vars qw($component_split $element_split);

sub make_xml_message {
	@xml_msg = ();
	push @xml_msg, $MESSAGE_HEADER;
	$xml_msg[0] =~ s!\n!!g		unless $indent_join;
	$xml_msg[0] =~ s!\t! !g		unless $indent_tab;

	my($cooked_message,@Segments,$segment,$s,$stating);

	$cooked_release_substitute = "\\".$advice_release_indicator."\\".$advice_release_indicator;
	$cooked_message_substitute = "\\".$advice_release_indicator."\\".$advice_segment_terminator;
	$cooked_segment_substitute = "\\".$advice_release_indicator."\\".$advice_element_seperator;
	$element_split             = "\\".$advice_element_seperator;
	$cooked_element_substitute = "\\".$advice_release_indicator."\\".$advice_component_seperator;
	$component_split           = "\\".$advice_component_seperator;

	$cooked_message = $edi_message;
	$cooked_message =~ s/$cooked_release_substitute/\002/g;
	$cooked_message =~ s/$cooked_message_substitute/\001/g;

	@Segments = split /$advice_segment_terminator/, $cooked_message;
	shift @Segments if ($Segments[0] =~ "^UNA");

	if ($Segments[0] =~ "^UNB.UNO") {
		$stating=substr $Segments[0], 7, 1;
		die "only UNOA to UNOC stating yet implemented"
			unless "ABC" =~ /$stating/;
	} else {
		$stating="C";
	}

	foreach $segment (@Segments) {
		$segment =~ tr/\0-\xff//CU if $stating == "C";
		$segment =~ s/\001/$advice_segment_terminator/g;
		resolve_segment($segment);
	}
	push @xml_msg , "</$MESSAGE_NAMESPACE:message>";

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
			$last_segment = $#xml_msg;
			undef $last_composite;

			foreach $i (1 .. $#Elements) {
				$element  = $Elements[$i];
				$element =~ s/\001/$advice_element_seperator/g;

				if ($Elements[$i] ne '') {
					# resolve_element
					push @xml_msg, '<!-- *** '.$Codes[$i].'='.$Elements[$i].' -->' if ($debug>1);
					resolve_element($Codes[$i], $Elements[$i]);
				}
			}
			if ($patch_segment) {
				push @xml_msg, '</'.$patch_segment.'>';
				undef $patch_segment;
			} else {
				push @xml_msg, '</'.$sgv[2].'>';
			}
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

		if ($cmv[2]) {
			push @xml_msg, '<'.$cmv[2].'>';
			$last_composite = $#xml_msg;
		}

		@Components = split /$component_split/, $cooked_element;
		@Codes = split / /, $cmv[0];

		foreach $i (0 .. $#Components) {
			$component = $Components[$i];
			if ($component ne '') {
				$component =~ s/\001/$advice_component_seperator/g;
				resolve_code($Codes[$i], $component);
			}
		}

		if ($cmv[2]) {
			if ($patch_composite) {
				push @xml_msg, '</'.$patch_composite.'>';
				undef $patch_composite;
			} else {
				push @xml_msg, '</'.$cmv[2].'>';
			}
		}
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

	$val =~ s/\002/$advice_release_indicator/g;
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
		if ($cd = $CODET{$code."\t".$val}) {
			@cdv=split /\t/, $cd;
			push @xml_msg, '<'.$mark.' '.$cdv[0].':code="'.$code.':'.encode_xml($val).'">'.encode_xml($cdv[1]).'</'.$mark.'>';
		} elsif ($cd = $EXTEND{"code:".$code.":".$val}) {
			@cdv=split /\t/, $cd;
			$mark =~ s/^[^:]+:/$MESSAGE_NAMESPACE:/;
			push @xml_msg, '<'.$mark.' '.$cdv[0].':code="'.$code.':'.encode_xml($val).'">'.encode_xml($cdv[1]).'</'.$mark.'>';
			$xml_msg[$last_segment] =~ s/^<[^:]+:/<$MESSAGE_NAMESPACE:/;
			$patch_segment = $xml_msg[$last_segment];
			$patch_segment =~ s/^<//;
			$patch_segment =~ s/[ >].*$//;
			if ($last_composite) {
				$xml_msg[$last_composite] =~ s/^<[^:]+:/<$MESSAGE_NAMESPACE:/;
				$patch_composite = $xml_msg[$last_composite];
				$patch_composite =~ s/^<//;
				$patch_composite =~ s/[ >].*$//;
			}
		} else {
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

	$advice_component_seperator = ":" unless $advice_component_seperator;
	$advice_element_seperator   = "+" unless $advice_element_seperator;
	$advice_decimal_notation    = "." unless $advice_decimal_notation;
	$advice_release_indicator   = "?" unless $advice_release_indicator;
	$advice_segment_terminator  = "'" unless $advice_segment_terminator;
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
	my ($opt,$val,$i,$j);
	my (@sgv,@cmv,@sgc,@cmc,$junk,$trans,$coded);

	if ($debug>1) {
		printf STDERR "(%s\n", $element;
		foreach $opt (keys (%options)) {
			printf STDERR "A%s=%s\n", $opt, $options{$opt};
		}
	}

	if ($edi_level == 0) {
		die "this is not XML::Edifact" if ($element !~ /^[^:]*:message/);
		$edi_valid   = 1;
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
			$edi_valid   = $SEGMR{$element};
			$edi_valid   = $EXTEND{"sgmt:".$element} unless ($edi_valid || ($XML::Edifact::MESSAGE_NAMESPACE eq "edifact"));
			if ($edi_valid) {
				@edi_segment = ($edi_valid);
				$edi_valid   = 1;
			}
			$edi_si      = 0;
			@edi_group   = ();
			$edi_gi      = 0;
		}
	}
	# to constrain edi_valid from edi_level 2 up adds robustness
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

		if ($i > $#sgc) {
			if ($XML::Edifact::MESSAGE_NAMESPACE ne "edifact") {
				$edi_valid = $EXTEND{"elmt:".$edi_segment[0].":".$element};
				$edi_valid = $EXTEND{"comp:".$edi_segment[0].":".$element} unless $edi_valid;
				if ($edi_valid) {
				    ($i,$j) = split / /, $edi_valid;
				    $edi_valid = 1;
				}
			} else {
				$edi_valid = 0;
			}
		}

		if ($i <= $#sgc) {
			$edi_si = $i;
			foreach $opt (keys (%options)) {
				if ($opt =~ "^[^:]*:code") {
					$val = $options{$opt};
					$val =~ s/^[^:]*://;
					$edi_group[$edi_gi] = $val;
				}
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
		} else {
			$edi_valid = 0;
		}
		if ($i > $#cmc) {
			if ($XML::Edifact::MESSAGE_NAMESPACE ne "edifact") {
				$edi_valid = $EXTEND{"elmt:".$edi_segment[0].":".$element};
				if ($edi_valid) {
				    ($j,$i) = split / /, $edi_valid;
				    $edi_valid = 1;
				}
			} else {
				$edi_valid = 0;
			}
		}

		if ($i <= $#cmc) {
			$edi_gi = $i;

			foreach $opt (keys (%options)) {
				if ($opt =~ "^[^:]*:code") {
					$val = $options{$opt};
					$val =~ s/^[^:]*://;
					$edi_group[$edi_gi] = $val;
				}
			}
		}
	    }
	} 

	carp "invalid xml-edifact at $edi_level level $element" unless $edi_valid;

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
	}
}

sub handle_char {
	my ($expat, $element) = @_;

	if ($element !~ /^[\n\r\t ]*$/) {
		if ($debug>1) {
			printf STDERR "-%s\n", $element;
		}

		$element =~ tr/\0-\x{ff}//UC;
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

use XML::Edifact;

    &XML::Edifact::open_dbm();
    &XML::Edifact::read_edi_message($ARGV[0]);
print   &XML::Edifact::make_xml_message();
    &XML::Edifact::close_dbm();
0;

---------------------------------------------------------------

use XML::Edifact;

    &XML::Edifact::open_dbm();
    &XML::Edifact::read_xml_message($ARGV[0]);
print   &XML::Edifact::make_edi_message();
    &XML::Edifact::close_dbm();
0;

=head1 DESCRIPTION

XML-Edifact started as Onyx-EDI which was a gawk script.
XML::Edifact-0.3x still shows its bad ancestry (a2p)
in some places.

The current module is able to generate some SDBM files for
the directory pointed to by open_dbm, by parsing the original
United Nations EDIFACT documents during Bootstrap.PL. Those
files will be stored during make install.

The first typical usage will read an EDIFACT message into a
buffer global to the package, and will print this message
as XML on STDOUT. The second usage will do the opposite.

Those two files will be installed as edi2xml and xml2edi
in your local bin directory.

New to XML::Edifact 0.34 are namespace migration and intend
handling - take a look at the test.pl for how to use them.
BUT WAIT - An object-oriented syntax is planned for the next
release! And I'm calling this release an interim, because I'm
just saving a stable state (I hope) before I start to muddle
all things around while going on an object(ive) raid.

If you have other EDIFACT files, I would like to include
them in the next version. I'm also open to any comments;
as they say, "everything is still in flux" !

=head1 AUTHOR

Michael Koehne, Kraehe@Copyleft.de

=head1 SEE ALSO

perl(1), XML::Parser(3), UN/EDIFACT Draft.

=cut

# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.2 version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

package XML::Edifact;

use strict;
use vars qw($VERSION $debug);
use vars qw(%SEGMT %COMPT %CODET %ELEMT);
use vars qw(%SEGMN %COMPN %CODEN);
use vars qw($raw_message $advice $advice_component_seperator);
use vars qw($advice_element_seperator $advice_decimal_notation);
use vars qw($advice_release_indicator $advice_segment_terminator);
use vars qw(%markstack $markstackp %markopt %markval);

use SDBM_File;
use Fcntl;

$VERSION='0.02';
$debug=1;

print "<!-- Hello from XML::EDIFACT -->\n"		if ($debug>1);

# ------------------------------------------------------------------------------

sub open_dbm {
    my ($directory,$fcntl) = @_;

    $fcntl = O_RDWR					 unless $fcntl eq "";

    printf "<!-- *** open_dbm -->\n"			if ($debug>1);

    tie(%SEGMT, 'SDBM_File', $directory.'/segment.tie',   $fcntl, 0640)	|| die "can not tie composite.tie:".$!;
    tie(%COMPT, 'SDBM_File', $directory.'/composite.tie', $fcntl, 0640)	|| die "can not tie composite.tie:".$!;
    tie(%CODET, 'SDBM_File', $directory.'/codes.tie',     $fcntl, 0640)	|| die "can not tie composite.tie:".$!;
    tie(%ELEMT, 'SDBM_File', $directory.'/element.tie',   $fcntl, 0640)	|| die "can not tie composite.tie:".$!;
}

sub close_dbm {
    untie(%SEGMT);
    untie(%COMPT);
    untie(%CODET);
    untie(%ELEMT);
}

sub open_num {
    my ($directory,$fcntl) = @_;

    $fcntl = O_RDWR					unless $fcntl eq "";

    printf "<!-- *** open_num -->\n"			if ($debug>1);

    tie(%SEGMN, 'SDBM_File', $directory.'/segment.num',   $fcntl, 0640)	|| die "can not tie composite.tie:".$!;
    tie(%COMPN, 'SDBM_File', $directory.'/composite.num', $fcntl, 0640)	|| die "can not tie composite.tie:".$!;
    tie(%CODEN, 'SDBM_File', $directory.'/codes.num',     $fcntl, 0640)	|| die "can not tie composite.tie:".$!;
}

sub close_num {
    untie(%SEGMN);
    untie(%COMPN);
    untie(%CODEN);
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
	print <<HERE_DTD_HEADER;
<!-- XML message produced by edi2xml.pl (c) Kraehe\@Bakunin.North.De -->

	<?xml version="1.0"?>
	<!DOCTYPE edicooked SYSTEM "edicooked02.dtd">

<edicooked>
HERE_DTD_HEADER
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
	print "</edicooked>\n";
}

# -----------------------------------------------------------------------------

sub resolve_segment {
	my($raw_segment) = @_;
	my($cooked_segment,@Elements,$element,$s,$i);
	my($sg,@sgv);
	my($segment_name);
	my($comment);

	if ($debug) {
		$comment = $raw_segment;
		$comment =~ s/--/__/g;
		printf "<!-- *** %s -->\n", $comment;
	}

	$cooked_segment = $raw_segment;
	$s = "\\".$advice_release_indicator."\\".$advice_element_seperator;
	$cooked_segment =~ s/$s/\001/g;

	$s = "\\".$advice_element_seperator;
	@Elements = split /$s/, $cooked_segment;

	$sg = $SEGMT{$Elements[0]."\t0"};
	@sgv = split("\t", $sg, 4);
	$segment_name = $sgv[3];

	printf "<!-- *** name %s -->\n", $segment_name	if ($debug>2);

	&open_mark($segment_name);

	for ($i = 1; $i <= $#Elements; $i++) {
		$element  = $Elements[$i];
		$element =~ s/\001/$advice_element_seperator/g;

		if ($Elements[$i] ne '') {
			&resolve_element(
				$segment_name, $Elements[0],
				$i, $Elements[$i]);
		}
	}
	&close_mark($segment_name);
}

# -----------------------------------------------------------------------------

sub resolve_element {
	my($name, $id, $pos, $raw_element) = @_;
	my($cooked_element,@Components,$component,$s,$i);
	my($sg,@sgv);
	my($cm,@cmv);

	printf "<!-- *** resolve element %s, %s, %s, %s -->\n", $name, $id, $pos, $raw_element if ($debug>1);

	$sg = $SEGMT{$id."\t".$pos};
	if ($sg ne '') {
		$cooked_element = $raw_element;
		$s = "\\".$advice_release_indicator."\\".$advice_component_seperator;
		$cooked_element =~ s/$s/\001/g;

		@sgv = split("\t", $sg, 4);

		if ($sgv[0] =~ '^[CS]') {
#			&open_mark($sgv[3]);
			$s = "\\".$advice_component_seperator;
			@Components = split(/$s/, $cooked_element, 9999);
			foreach $i (0 .. $#Components) {
				$component = $Components[$i];
				if ($component ne '') {
					$s = $advice_component_seperator;
					$component =~ s/\001/$s/g;
					print "<!-- lookup ".$sgv[0]."\t".($i+1)."\n"	if ($debug > 1);
					$cm = $COMPT{$sgv[0]."\t".($i+1)};
					print "<!-- is ".$cm."\n" 			if ($debug > 1);
					@cmv = split("\t", $cm, 4);
					&resolve_code($cmv[3], $cmv[0], $component);
				}
			}

#			&close_mark($sgv[3]);
		}
		else {
			$s = $advice_component_seperator;
			$cooked_element =~ s/\001/$s/g;
			&resolve_code($sgv[3], $sgv[0], $cooked_element);
		}
	}
	else {
		printf "<!-- *** %s\t%s\t%s -->\n", $id, $pos, $raw_element;
	}
}

# -----------------------------------------------------------------------------

sub resolve_code {
	my($mark, $id, $val) = @_;
	my($cd,$canonelem);

	$mark=$ELEMT{$id};
	printf "<!-- *** resolve code %s, %s, %s -->\n", $mark, $id, $val if ($debug>1);

	&open_mark($mark);
	if ($CODET{$id."\t"} ne "") {
		$cd = $CODET{$id."\t".$val};
		&add_code($mark, $val);
		if ($cd ne '') {
			&add_val($mark, $cd);
		}
		else {
			&add_val($mark, $val);
		}
	}
	else {
		&add_val($mark, $val);
	}
	&close_mark($mark);
}

# -----------------------------------------------------------------------------

sub open_mark {
	my($mark) = @_;

	$mark=&recode_mark($mark);
	printf "<!-- *** open mark %d, %s -->\n", $markstackp, $mark if ($debug>2);

	$markstack{++$markstackp} = $mark;
	$markopt{$markstackp} = '';
	$markval{$markstackp} = '';
}

sub close_mark {
	my($mark) = @_;
	my($v,$vt,$s);

	$mark=&recode_mark($mark);
	printf "<!-- *** close mark %d, %s -->\n", $markstackp-1, $mark if ($debug>2);
	
	$v = '';
	if ($markval{$markstackp} ne '') {
		if ($markval{$markstackp} !~ "[</\n]") {
			if ($markopt{$markstackp} ne '') {
				$vt = " is=\"" . $markopt{$markstackp} . "\"";
			}
			else {
				$vt = '';
			}
			if (($markval{$markstackp} ne '') && ($markval{$markstackp} ne $markopt{$markstackp})) {
				$v = sprintf('<%s%s>%s</%s>', $markstack{$markstackp}, $vt, $markval{$markstackp}, $markstack{$markstackp});
			}
			else {
				$v = sprintf('<%s%s/>', $markstack{$markstackp}, $vt, $markval{$markstackp});
			}
		}
		elsif ($markval{$markstackp} ne '') {
			if ($markopt{$markstackp} ne '') {
				$vt = " is=\"" . $markopt{$markstackp} . "\"";
			}
			else {
				$vt = '';
			}
			$v = sprintf("<%s%s>\n%s\n</%s>", 
				$markstack{$markstackp}, 
				$vt, 
				$markval{$markstackp}, 
				$markstack{$markstackp});
		}
		if ($v ne '') {
			if ($markstackp != 1) {
				$s = '^', $v =~ s/$s/  /;
				$s = "\n", $v =~ s/$s/\n  /g;
				&add_val($markstack{$markstackp - 1}, $v);
			}
			else {
				printf "%s\n", $v;
			}
		}
	}
	$markopt{$markstackp} = '';
	$markval{$markstackp} = '';
	$markstack{$markstackp--} = '';
}

sub add_code {
	my($mark, $code) = @_;
	my($k);

	$mark=&recode_mark($mark);
	printf "<!-- *** add code %s, %s -->\n", $mark, $code if ($debug>3);
	
	for ($k = 1; $k <= $markstackp; $k++) {
		if ($markstack{$k} eq $mark) {
			$markopt{$k} = $markopt{$k} ? $markopt{$k} . ':' : '' . $code;
			last;
		}
	}
}

sub add_val {
	my($mark, $val) = @_;
	my($k);

	$mark=&recode_mark($mark);
	printf "<!-- *** add val %s, %s -->\n", $mark, $val if ($debug>3);
	
	for ($k = 1; $k <= $markstackp; $k++) {
		if ($markstack{$k} eq $mark) {
			if ($markval{$k} ne '') {
				$markval{$k} = $markval{$k} . "\n" . $val;
			}
			else {
				$markval{$k} = $val;
			}
			last;
		}
	}
}

# ------------------------------------------------------------------------------
1;           					# modules must return true
# ------------------------------------------------------------------------------
__END__

=head1 NAME

XML::Edifact - Perl module for handling XML/Edifact messages.

=head1 SYNOPSIS

use XML::Edifact;

&XML::Edifact::open_dbm("data");
&XML::Edifact::read_message($ARGV[0]);
&XML::Edifact::process_message();
&XML::Edifact::close_dbm();

0;

=head1 DESCRIPTION

XML-Edifact started as Onyx-EDI which was a gawk script.
XML::Edifact-0.02 still shows its bad anchesor called a2p
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

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..19\n"; }
END {print "not ok 1\n" unless $loaded;}
use XML::Edifact;
use XML::Edifact::Config;
use File::Spec;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

$XML::Edifact::Config::URL=".";
 XML::Edifact::open_dbm($XML::Edifact::Config::TST);
$XML::Edifact::indent_join="\n";
$XML::Edifact::indent_tab ="  ";

print "ok 2\n";

$ok=3;

foreach $edi (
	'linux', 'nad_buyer', 'pia_isbn', 'editeur',
	'elfe2', 'eva2', 'springer', 'teleord'
	) {
	XML::Edifact::read_edi_message(File::Spec->catfile("examples",$edi.".edi"));

	open(OUTFILE,">".File::Spec->catfile("html",$edi.".xml"));
	select(OUTFILE);
	print	XML::Edifact::make_xml_message();
	select(STDOUT);
	close(OUTFILE);

	print "ok $ok\n"; $ok++;

	# do not cheat
	$XML::Edifact::edi_message='';

	open(OUTFILE,">".File::Spec->catfile("html",$edi.".edi"));
	select(OUTFILE);
	print	XML::Edifact::make_edi_message();
	select(STDOUT);
	close(OUTFILE);

	print "ok $ok\n"; $ok++;
}

XML::Edifact::close_dbm();

print "ok $ok\n"; $ok++;

0;

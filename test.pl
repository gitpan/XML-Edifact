# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..21\n"; }
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

#$XML::Edifact::Config::URL=".";
 XML::Edifact::open_dbm($XML::Edifact::Config::TST);
$XML::Edifact::indent_join="\n";
$XML::Edifact::indent_tab ="  ";

print "ok 2\n";

$ok=3;

foreach $edi (
	'linux', 'nad_buyer', 'pia_isbn', 'editeur',
	'elfe2', 'eva2', 'springer', 'teleord', 'lineitem'
	) {
	if ($edi eq 'teleord') {
		$XML::Edifact::MESSAGE_NAMESPACE="teleord";
		XML::Edifact::eval_xml_edifact_headers();
		tie(%XML::Edifact::EXTEND, 'SDBM_File', "code_lists/teleord", O_RDONLY, 0777) || die "tie:".$!;
	}
	XML::Edifact::read_edi_message(File::Spec->catfile("examples",$edi.".edi"));

	open(OUTFILE,">".File::Spec->catfile("html","EX",$edi.".xml"));
	select(OUTFILE);
	print	XML::Edifact::make_xml_message();
	select(STDOUT);
	close(OUTFILE);

	print "ok $ok\n"; $ok++;

	# do not cheat
	$XML::Edifact::edi_message='';

	open(OUTFILE,">".File::Spec->catfile("html","EX",$edi.".edi"));
	select(OUTFILE);
	print	XML::Edifact::make_edi_message();
	select(STDOUT);
	close(OUTFILE);

	print "ok $ok\n"; $ok++;
}

XML::Edifact::close_dbm();

print "ok $ok\n"; $ok++;

open(OUTFILE,">".File::Spec->catfile("html","EX","index.html"));
print OUTFILE <<'!1!';
<h1>Example Files</h1>
<h2>Publisher, Bookshop, Library order chain</h2>
<ul>
<li>[ <a href="editeur.edi">EDI</a> ]
    [ <a href="editeur.xml">XML</a> ] EDItEUR
<li>[ <a href="springer.edi">EDI</a> ]
    [ <a href="springer.xml">XML</a> ] Springer Verlag
<li>[ <a href="teleord.edi">EDI</a> ]
    [ <a href="teleord.xml">XML</a> ] TeleOrdering
</ul>
<h2>ETIS phon bill</h2>
<ul>
<li>[ <a href="elfe2.edi">EDI</a> ]
    [ <a href="elfe2.xml">XML</a> ] ELFE
<li>[ <a href="eva2.edi">EDI</a> ]
    [ <a href="eva2.xml">XML</a> ] EVA
</ul>
<h2>Message fragment</h2>
<ul>
<li>[ <a href="linux.edi">EDI</a> ]
    [ <a href="linux.xml">XML</a> ] Linux
<li>[ <a href="nad_buyer.edi">EDI</a> ]
    [ <a href="nad_buyer.xml">XML</a> ] Buyer
<li>[ <a href="pia_isbn.edi">EDI</a> ]
    [ <a href="pia_isbn.xml">XML</a> ] ISBN
<li>[ <a href="lineitem.edi">EDI</a> ]
    [ <a href="lineitem.xml">XML</a> ] Line Item
</ul>
!1!
close(OUTFILE);

0;

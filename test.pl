# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..21\n"; print "loading ... "; }
END {print "not ok 1\n" unless $loaded;}
use XML::Edifact;
use XML::Edifact::Config;
use Digest::MD5;
use File::Spec;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

print "open_dbm ... ";

#$XML::Edifact::Config::URL=".";
 XML::Edifact::open_dbm($XML::Edifact::Config::TST);
$XML::Edifact::indent_join="\n";
$XML::Edifact::indent_tab ="  ";

print "ok 2\n";

$ok=3;

%checksums = (
	'linux.xml'	=> '874f449e78c55a3efc2d574154627351',
	'linux.edi'	=> '73a0100f6ee3500499ea8b278a0ffaa2',
	'nad_buyer.xml'	=> '586b63c8b69b3d8db42a1b973a56b1da',
	'nad_buyer.edi'	=> '4a4c127542fa23a8e95b2a8d8b74d796',
	'pia_isbn.xml'	=> 'dd1568bfa236160db9c314c1a9994692',
	'pia_isbn.edi'	=> '3ca92278edd89355391dedfe20fe7dd0',
	'editeur.xml'	=> '8f3e3d0abd2a74718bc2cac3a348f08f',
	'editeur.edi'	=> '769294d7655df1ae781bdd6e44e11d28',
	'elfe2.xml'	=> 'ed7fb2464a4894586d4465902955c03f',
	'elfe2.edi'	=> '55c0133abcd7f7e629c88704b9f87466',
	'eva2.xml'	=> '1b5d70e004a50480c2387945ec11ad54',
	'eva2.edi'	=> '357628b2813b3676a8c1468faab058a7',
	'springer.xml'	=> '3af3198516036147748e1f0e7b639126',
	'springer.edi'	=> '71f84cd62f9833c69d72c5a53c28aacc',
	'teleord.xml'	=> 'd8eeb8600dd5362637c6825d7a297fef',
	'teleord.edi'	=> 'aae467e7810d9aabc0bd3174f22d9831',
	'lineitem.xml'	=> 'e2d33f6413d1c3dd3b17cc2fd91dcd93',
	'lineitem.edi'	=> 'f13cdc7d5258bb4eac728f30b389eb32'
	);

foreach $edi (
	'linux', 'nad_buyer', 'pia_isbn', 'editeur',
	'elfe2', 'eva2', 'springer', 'teleord', 'lineitem'
	) {
	printf "%-16s ... ", $edi. ".xml";

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

	open(OUTFILE,"<".File::Spec->catfile("html","EX",$edi.".xml"));
	$md5=Digest::MD5->new->addfile(*OUTFILE)->hexdigest;
	close(OUTFILE);
	print $md5, " ... ";
	print "not " if $md5 ne $checksums{$edi.".xml"};

	print "ok $ok\n"; $ok++;

	printf "%-16s ... ", $edi. ".edi";

	# do not cheat
	$XML::Edifact::edi_message='';

	open(OUTFILE,">".File::Spec->catfile("html","EX",$edi.".edi"));
	select(OUTFILE);
	print	XML::Edifact::make_edi_message();
	select(STDOUT);
	close(OUTFILE);

	open(OUTFILE,"<".File::Spec->catfile("html","EX",$edi.".edi"));
	$md5=Digest::MD5->new->addfile(*OUTFILE)->hexdigest;
	close(OUTFILE);
	print $md5, " ... ";
	print "not " if $md5 ne $checksums{$edi.".edi"};

	print "ok $ok\n"; $ok++;
}

print "close_dbm ... ";

XML::Edifact::close_dbm();

print "ok $ok\n"; $ok++;

open(OUTFILE,">".File::Spec->catfile("html","EX","index.html"));
print OUTFILE <<'!1!';
<html>
<head>
<title>Example Files</title>
<link rel="stylesheet" href="http://www.w3.org/StyleSheets/Core/Oldstyle" type="text/css">
</head>
<body>
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
</body>
</html>
!1!
close(OUTFILE);

0;

use ExtUtils::MakeMaker;
use File::Spec;
use Config;

eval {
	require XML::Edifact::Config;

	$URL = $XML::Edifact::Config::URL;
	$DIR = $XML::Edifact::Config::DIR;
};

print <<'!1!';

I know I should check for those 99 possible places, but I prefer to ask :-)

XML::Edifact will produce XML files that need a place for their document
type definitions. I prefer to have DTD's on a webserver, so the default
is a http URL.

You may want to store your DTD's relative. A single dot will allow
validating parsers to find the DTD in the same directory.

Perhaps you want the DTD and examples stored local on your disk so
/usr/local/share/xml/xml-edifact might be the right answer for URL.
You should not prefix a local URL with file: you use your operating
system path.

If you dislike XML::Edifact installing the DTD and the example files
to a public directory, answer the dot "." as URL, "/tmp/xml-edifact"
as a directory and delete "/tmp/xml-edifact" by hand after install.

Anyway, do not provide a trailing slash, File::Spec will do that!

!1!

$URL = "http://localhost/xml-edifact"         unless $URL;
$DIR = "/usr/local/apache/htdocs/xml-edifact" unless $DIR;

$URL = prompt "URL for public documents",$URL;
$DIR = prompt "Directory on this system",$DIR;

if (! -d $DIR) {
	mkdir "$DIR",0777 or die "mkdir:".$!;
}

$XMLEDI=File::Spec->catdir("XML","Edifact");
mkdir $XMLEDI,0777 unless -d $XMLEDI;

$DAT=File::Spec->catdir($Config{'installsitelib'},"XML","Edifact","d96b");
$TST=File::Spec->catdir("blib","lib","XML","Edifact","d96b");

open OUTFILE,">".File::Spec->catdir("XML","Edifact","Config.pm");
print  OUTFILE 'package XML::Edifact::Config;'."\n";
print  OUTFILE 'use strict;'."\n";
print  OUTFILE 'use vars qw($URL $DIR $DAT $TST);'."\n";
printf OUTFILE '$URL="%s";'."\n", $URL;
printf OUTFILE '$DIR="%s";'."\n", $DIR;
printf OUTFILE '$DAT="%s";'."\n", $DAT;
printf OUTFILE '$TST="%s";'."\n", $TST;
print  OUTFILE '1;'."\n";
close OUTFILE;

print "\n";

WriteMakefile(
    'NAME'	   => 'XML::Edifact',
    'AUTHOR'       => 'kraehe@copyleft.de',
    'ABSTRACT'     => 'an aproach towards XML/EDI as a prototype in perl',
    'VERSION_FROM' => 'XML/Edifact.pm',
    'PM'           => { 'XML/Edifact.pm'        => '$(INST_LIBDIR)/Edifact.pm',
 			'XML/Edifact/Config.pm' => '$(INST_LIBDIR)/Edifact/Config.pm',
    			 },
    'PL_FILES'     => { 'Bootstrap.PL'          => '$(INST_LIBDIR)/Edifact/d96b/.exists',
 			'bin/xml2edi.PL'        => 'bin/xml2edi',
 			'bin/edi2xml.PL'        => 'bin/edi2xml'
			},
    'EXE_FILES'    => [ 'bin/edi2xml', 'bin/xml2edi' ],
    'MAN3PODS'     => { 'XML/Edifact.pm'        => '$(INST_MAN3DIR)/XML::Edifact.3' },
    'dist'         => { 'COMPRESS' => 'gzip -v -f -9', 'SUFFIX' => 'gz' },
    'PREREQ_PM'    => { 'XML::Parser' => 2.27,
    			'Digest::MD5' => 2.09
			},
);

sub MY::postamble {
	return('install:: '.$main::DIR."/.exists\n".
	       $main::DIR."/.exists : html/.exists\n".
	       "\t".'$(MOD_INSTALL) html '.$main::DIR."\n".
	       "\t".'touch '.$main::DIR."/.exists\n");
}

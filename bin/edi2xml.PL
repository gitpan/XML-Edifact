# -*- perl -*-

use strict;

my $script = <<'SCRIPT';
~startperl~

# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.3* version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

# -----------------------------------------------------------------------------

use	XML::Edifact;

XML::Edifact::open_dbm();
XML::Edifact::read_edi_message($ARGV[0]);

# $XML::Edifact::indent_join="\n";
# $XML::Edifact::indent_tab="\t";

print XML::Edifact::make_xml_message();

XML::Edifact::close_dbm();

0;
SCRIPT

use Config;

my $file = $ARGV[0];

$script =~ s/\~(\w+)\~/$Config{$1}/eg;
if (!(open(FILE, ">$file"))  ||
    !(print FILE $script)  ||
    !(close(FILE))) {
    die "Error while writing $file: $!\n";
}
print "Extracted $file from ",__FILE__," with variable substitutions.\n";

# end
0;

#!/usr/local/bin/perl
# 
# Copyright (c) 1998 Michael Koehne <kraehe@bakunin.north.de>
# 
# XML::Edifact is free software. You can redistribute and/or
# modify this copy under terms of GNU General Public License.
#
# This is a 0.3* version: Anything is still in flux.
# DO NOT EXPECT FURTHER VERSION TO BE COMPATIBLE!

eval 'exec /usr/local/bin/perl -S $0 ${1+"$@"}'
	if $running_under_some_shell;

# -----------------------------------------------------------------------------

use	XML::Edifact;

	&XML::Edifact::open_dbm("data");
	&XML::Edifact::read_xml_message($ARGV[0]);
print	&XML::Edifact::make_edi_message();
	&XML::Edifact::close_dbm();
0;

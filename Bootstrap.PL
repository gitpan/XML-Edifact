#!perl
# Copyright (c) 1999 Michael Koehne <kraehe@bakunin.north.de>

use XML::Edifact;
use File::Spec;
use SDBM_File;
use Fcntl;

$DATA=File::Spec->catdir("blib","lib","XML","Edifact","d96b");

mkdir "html",0777 unless -d "html";
mkdir $DATA, 0777 unless -d $DATA;

XML::Edifact::open_dbm( $DATA, O_RDWR|O_CREAT );

#------------------------------------------------------------------------------#

$run=File::Spec->catdir("boot","segment.run");   $req_ok = require $run;
$run=File::Spec->catdir("boot","composite.run"); $req_ok = require $run;
$run=File::Spec->catdir("boot","element.run");   $req_ok = require $run;
$run=File::Spec->catdir("boot","annex_b.run");   $req_ok = require $run;
$run=File::Spec->catdir("boot","codes.run");     $req_ok = require $run;
$run=File::Spec->catdir("boot","dtd.run");       $req_ok = require $run;

#------------------------------------------------------------------------------#

XML::Edifact::close_dbm( );

open TOUCH,">".File::Spec->catfile($DATA,".exists");
close TOUCH;

0;

#!/bin/sh

cd doc

sgml2html XML-Edifact.sgml
sgml2txt XML-Edifact.sgml
col -b < XML-Edifact.txt > ../README

sgml2html RDF_and_XML-Namespaces.sgml
sgml2txt  RDF_and_XML-Namespaces.sgml

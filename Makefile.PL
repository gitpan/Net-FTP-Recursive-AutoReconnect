#!/usr/bin/perl

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'Net::FTP::Recursive::AutoReconnect',
    'AUTHOR'            => '-',
    'ABSTRACT'          => 'Net-FTP-Recursive with autorecoonect',
    'VERSION_FROM'	=> 'AutoReconnect.pm', # finds $VERSION
    'PREREQ_PM'		=> {
                             Net::FTP => 1.00
			   },

);

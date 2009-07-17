# Makefile.PL for Win32::GUI::HyperLink
# $Id: Makefile.PL,v 1.4 2005/04/24 18:21:24 Robert May Exp $

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Win32::GUI::HyperLink',
    AUTHOR              => 'Robert May <rmay@popeslane.clara.co.uk>',
    VERSION_FROM        => 'lib\Win32\GUI\HyperLink.pm',
    ABSTRACT_FROM       => 'lib\Win32\GUI\HyperLink.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Win32::GUI' => 0,
        'Win32::API' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Win32-GUI-HyperLink-*' },
);

# Add a new rule to make a ppm distribution
sub MY::postamble {
    return <<'MAKE_PPM';
ppm:
  $(RM_F) $(DISTVNAME)-PPM.zip
  make_ppm --arch=""
  $(ZIP) -9 $(DISTVNAME)-PPM.zip README-PPM.TXT $(DISTNAME).ppd $(DISTNAME).tar.gz
  $(RM_F) pod2htmld.tmp pod2htmli.tmp $(DISTNAME).ppd $(DISTNAME).tar.gz


MAKE_PPM
}

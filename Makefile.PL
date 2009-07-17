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
        'Win32::GUI' => 1.0,
        'Win32::GUI::BitmapInline' => 0.02,
        'Win32::API' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Win32-GUI-HyperLink-*' },
);

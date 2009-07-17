# Check that the module's Launch method is OK
# $Id: 05.method-Launch.t,v 1.3 2005/04/24 17:29:07 Robert May Exp $
use strict;
use warnings;

use Test::More tests => 1;

use Win32::GUI::Hyperlink;

my $parent = Win32::GUI::Window->new(
);

my $text = 'http://www.example.com';

my $obj = Win32::GUI::HyperLink->new(
  $parent,
  -text => $text,
);

# Can't really test if someone's default drowser launches, so
# we'll just check that it returns undef if there's no link
# available

$obj->Url("");
ok( !defined($obj->Launch()), "Don't Launch empty link" );

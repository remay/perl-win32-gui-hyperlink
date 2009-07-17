# Check that the module's Url method is OK
# $Id: 04.method-Url.t,v 1.2 2005/03/01 01:31:43 Robert May Exp $

use Test::More tests => 5;

use Win32::GUI::Hyperlink;

my $parent = Win32::GUI::Window->new(
);

my $text = 'http://www.perl.org';

my $obj = Win32::GUI::HyperLink->new(
  $parent,
  -text => $text,
);

is( $obj->Url(), $text, "Retrieve initial link" );

my $text2 = 'mailto:fred@example.com';

is( $obj->Url($text2), $text2, "Set new link");
is( $obj->Url(), $text2, "Retrieve set link" );

is( $obj->Url(""), "", "Set empty link");
is( $obj->Url(), "", "Retrieve empty link");

# Check that the module has the public methods that we are expecting
# $Id: 02.methods.t,v 1.2 2005/03/01 01:31:43 Robert May Exp $

use Test::More tests => 1;

use Win32::GUI::Hyperlink;

# new, Url, Launch
can_ok('Win32::GUI::HyperLink', qw(new Url Launch) );

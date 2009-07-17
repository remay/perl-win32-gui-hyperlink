# Check that the module has the public methods that we are expecting
# $Id: 02.methods.t,v 1.3 2005/04/24 17:29:07 Robert May Exp $
use strict;
use warnings;

use Test::More tests => 1;

use Win32::GUI::Hyperlink;

# new, Url, Launch
can_ok('Win32::GUI::HyperLink', qw(new Url Launch) );

# Check that the module loads stand-alone
# $Id: 01.load.t,v 1.3 2005/04/24 17:29:07 Robert May Exp $
use strict;
use warnings;

use Test::More tests => 1;

BEGIN {
use_ok( 'Win32::GUI::HyperLink' );
}

diag( "Testing Win32::GUI::HyperLink $Win32::GUI::HyperLink::VERSION" );

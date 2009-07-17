# Check that the module loads stand-alone
# $Id: 01.load.t,v 1.2 2005/03/01 01:31:43 Robert May Exp $

use Test::More tests => 1;

BEGIN {
use_ok( 'Win32::GUI::HyperLink' );
}

diag( "Testing Win32::GUI::HyperLink $Win32::GUI::HyperLink::VERSION" );

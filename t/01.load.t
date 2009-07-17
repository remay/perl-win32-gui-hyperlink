# Check that the module loads stand-alone
use Test::More tests => 1;

BEGIN {
use_ok( 'Win32::GUI::HyperLink' );
}

diag( "Testing Win32::GUI::HyperLink $Win32::GUI::HyperLink::VERSION" );

# Win32::GUI::HyperLink dependancies check
# $Id: 00.dependancies.t,v 1.2 2005/03/01 01:31:42 Robert May Exp $

use Test::More tests => 3;

eval { use Win32::GUI 1.0 };
eval { use Win32::GUI::BitmapInline 0.02 };
eval { use Win32::API };

if (ok($Win32::GUI::VERSION, "Win32::GUI v1.0 or higher" )) {
  diag("Win32::GUI version $Win32::GUI::VERSION found");
} else {
  # If we don't have Win32::GUI 1.0 or higher, no point in continuing
  # Note the format of the 'Bail out!' text is vital to Test::Harness
  # spotting this.
  print "Bail out! Win32::GUI v1.0 or higher required\n";
}

# Win32::GUI::BitmapInline not required
SKIP: {

    skip "Win32::GUI::BitmapInline v0.02 or higher not installed.", 1 if not defined $Win32::GUI::BitmapInline::VERSION;

    pass("Win32::GUI::BitmapInline v0.02 or higher") and
      diag("Win32::GUI::BitmapInline version $Win32::API::VERSION found");
}

# Win32::API not required
SKIP: {

    skip "Win32::API not installed. See documentation for details", 1 if not defined $Win32::API::VERSION;

    pass("Win32::API") and
      diag("Win32::API version $Win32::API::VERSION found");
}

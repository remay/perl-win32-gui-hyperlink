# Check that the module's new method is OK
  use Test::More tests => 19;

  use Win32::GUI::Hyperlink;
  my $hasWin32API = defined $Win32::API::VERSION; # WIn32::GUI loaded if available by HyperLink

  my ($obj, $alt_obj);

  my $callback = sub {};

  my $parent = Win32::GUI::Window->new(
  );

  my $text = 'http://www.perl.org';

  # the constructor
  $obj = Win32::GUI::HyperLink->new(
    $parent,
    -text => $text,
  );

isa_ok($obj, 'Win32::GUI::HyperLink');

  # check inheritance
isa_ok($obj, 'Win32::GUI::Label');

  # the alternative constructor
  $alt_obj = $parent->AddHyperLink(
    -text => $text,
  );

isa_ok($alt_obj, 'Win32::GUI::HyperLink');

  # check inheritance
isa_ok($alt_obj, 'Win32::GUI::Label');

  # done with the alternate
  $alt_obj = undef;

  # -url not supplied, defaults to -text
  $obj = undef;
  $obj = Win32::GUI::HyperLink->new(
    $parent,
    -text => $text,
  );
is($obj->Url(), $text, "-url defaults to -text");

  # -text not supplied, defaults to -url
  $obj = undef;
  $obj = Win32::GUI::HyperLink->new(
    $parent,
    -url => $text,
  );
is($obj->Text(), $text, "-text defaults to -url");

  # neither -url or -text defined, both empty
  $obj = undef;
  $obj = Win32::GUI::HyperLink->new(
    $parent,
  );
is($obj->Text(), "", "-text: -text and -url empty");
is($obj->Url(), "", "-url: -text and -url empty");

  # check that onMouseIn event is stored
  $obj = undef;
  $obj = Win32::GUI::HyperLink->new(
    $parent,
    -url => $text,
    -onMouseIn => $callback,
  );
ok($obj->{-onMouseIn} == $callback, "MouseIn event callback stored");

  # check that onMouseOut event is stored
  $obj = undef;
  $obj = Win32::GUI::HyperLink->new(
    $parent,
    -url => $text,
    -onMouseOut => $callback,
  );
ok($obj->{-onMouseOut} == $callback, "MouseOut event callback stored");

  # check underline

  # if never underline, no font handles stored, and no reference to new font
  # if hover, 2 font handles are stored and reference to new font;
  # if underline always, then no font handles, just reference to new font

  ###############
  # sub underline_state returns: 0 - never underline, 1 - underline on hover
  #                              2 - always underline, 3 - error
  sub underline_state
  {
    if (defined $obj->{_u_font_ref}) {
      if(defined $obj->{_hNfont} and defined $obj->{_hUfont}) {
        return 1;
      } 
      if(!defined $obj->{_hNfont} and !defined $obj->{_hUfont}) {
        return 2;
      }
      return 3;
    } else {
      if(defined $obj->{_hNfont} or defined $obj->{_hUfont}) {
        return 3;
      }
      return 0;
    }
  }

  # DEFAULT: underline should default to hover if Win32::API available, always underlined if not
  $obj = undef;
  $obj = Win32::GUI::HyperLink->new(
    $parent,
    -url => $text,
  );

ok( (( !$hasWin32API and undederline_state() == 2)
       or ($hasWin32API and underline_state() == 1) ), "Default underline style");
  diag "As you don't have Win32::API, underline on hover becomes underline always" if !$hasWin32API;

  # SET NO UNDERLINE:
  $obj = undef;
  $obj = Win32::GUI::HyperLink->new(
    $parent,
    -url => $text,
    -underline => 0,
  );

ok( underline_state() == 0, "Never underline");

  # SET underline on hover - results as per default
  $obj = undef;
  $obj = Win32::GUI::HyperLink->new(
    $parent,
    -url => $text,
    -underline => 1,
  );

ok( (( !$hasWin32API and undederline_state() == 2)
       or ($hasWin32API and underline_state() == 1) ), "underline on hover");

  # SET underline always
  $obj = undef;
  $obj = Win32::GUI::HyperLink->new(
    $parent,
    -url => $text,
    -underline => 2,
  );

ok( underline_state() == 2, "Always underline");

  # check that onClick handler is set
  $obj = undef;
  $obj = Win32::GUI::HyperLink->new(
    $parent,
    -url => $text,
  );

ok(defined $obj->GetEvent("Click"), "Click handler set");

  # check that onMouseMove handler is set
ok(defined $obj->GetEvent("MouseMove"), "MouseMove handler set");

  # check that an overriden onClick handler is set
  $obj = undef;
  $callback = sub {};
  $obj = Win32::GUI::HyperLink->new(
    $parent,
    -url => $text,
    -onClick => $callback,
  );

ok($obj->GetEvent("Click") == $callback, "override Click handler set");

  # check that an overridden onMouseMove handler gets stored
  $obj = undef;
  $callback = sub {};
  $obj = Win32::GUI::HyperLink->new(
    $parent,
    -url => $text,
    -onMouseMove => $callback,
  );

ok($obj->{-onMouseMove} == $callback, "override MouseMove handler stored");
ok(!($obj->GetEvent("MouseMove") == $callback), "override MouseMove handler is not actual handler");


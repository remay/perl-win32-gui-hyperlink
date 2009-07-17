package Win32::GUI::HyperLink;
# $Id: HyperLink.pm,v 1.4 2005/04/24 17:29:07 Robert May Exp $

use warnings;
use strict;
use Carp;

use Win32::GUI;
use base qw(Win32::GUI::Label);

=head1 NAME

Win32::GUI::HyperLink - A Win32::GUI Hyperlink control

=cut

our $VERSION = sprintf("%d.%02d", q$Name: REL-0-13 $ =~ /(\d+)-(\d+)/, 999, 99);

=head1 SYNOPSIS

Win32::GUI::HyperLink is a Win32::GUI::Label that
acts as a clickable hyperlink.  By default
it has a 'hand' Cursor, is drawn in blue text rather than black and the
text is dynamically underlined when the mouse moves over the text.
The Label can be clicked to launch a hyperlink, and supports onMouseIn
and onMouseOut events to allow (for example) the link url to be
displayed while the mouse is over the link.

    use Win32::GUI::HyperLink;

    my $hyperlink = Win32::GUI::HyperLink->new($parent_window, %options);

    my $hyperlink = $parent_window->AddHyperLink(%options);

    $url = $hyperlink->Url();

    $hyperlink->Url($url);

    $hyperlink->Launch();

Win32::GUI::HyperLink is a sub-class of Win32::GUI::Label, and so
supports all the options and methods of Win32::GUI::Label.  See
the L<Win32::GUI::Label> documentation for further information.
Anywhere that behaviour differs is highlighted below.

See the F<HyperLinkDemo.pl> script for examples of using the
functionality. This demo script can be found in the F<.../Win32/GUI/demos/HyperLink>
directory beneath the installation directory.

=cut

######################################################################
# Some useful constants
######################################################################
# Don't "use constant", as it fails with earlier versions of perl
sub IDC_HAND        () {32649};
sub WM_SETFONT      () {48};
sub SW_SHOWNORMAL   () {1};
sub WM_MOUSEMOVE    () {512};
sub WM_LBUTTONDOWN  () {513};

sub UNDERLINE_NONE  () {0};
sub UNDERLINE_HOVER () {1};
sub UNDERLINE_ALWAYS() {2};

sub API_NONE        () {0};
sub API_HAS_WIN32GUI() {1};
sub API_HAS_WIN32API() {2};

######################################################################
# package global storage
######################################################################
# If we create a cursor object, then store it here so that
# we only create one cursor object regardless of how many HyperLink
# objects we have.  See function _get_hand_cursor().
our $_hand_cursor = undef;
our $_has_loadcursor   = API_NONE;
our $_has_getcapture   = API_NONE;
our $_has_shellexecute = API_NONE;

######################################################################
# Some Win32::GUI versions are missing some of the functions that
# are used - find out which are available, and then try to use
# Win32::API for those that are not.
######################################################################
# LoadCursor   - added after V1.0
$_has_loadcursor   = API_HAS_WIN32GUI if (Win32::GUI->can('LoadCursor'));
# GetCapture   - added after V1.0
$_has_getcapture   = API_HAS_WIN32GUI if (Win32::GUI->can('GetCapture'));
# ShellExecute - added after V1.0
$_has_shellexecute = API_HAS_WIN32GUI if (Win32::GUI->can('ShellExecute'));

######################################################################
# The Win32::API calls we want to make:
######################################################################
# Dont load Win32::API unless it is available ...
BEGIN { eval "use Win32::API"; };

# and try to load the calls we are still missing

my $LoadCursor   = undef;
my $GetCapture   = undef;
my $ShellExecute = undef;
# if Win32::API is available
if (defined $Win32::API::VERSION) {
  if($_has_loadcursor == API_NONE) {
    # HCURSOR LoadCursor(HINSTANCE hInstance, LPCTSTR lpCursorName);
    $LoadCursor = Win32::API->new('User32', 'LoadCursor', 'NN', 'N');
    $_has_loadcursor = API_HAS_WIN32API if(defined($LoadCursor));
  }
  if($_has_getcapture == API_NONE) {
    # HWND GetCapture(VOID);
    $GetCapture = Win32::API->new("User32","GetCapture", "", "N");
    $_has_getcapture = API_HAS_WIN32API if(defined($GetCapture));
  }
  if($_has_shellexecute == API_NONE) {
    # HINSTANCE ShellExecute(HWND hwnd, LPCTSTR lpOperation, LPCTSTR lpFile,
    #      LPCTSTR lpParameters, LPCTSTR lpDirectory, INT nShowCmd);
    $ShellExecute = Win32::API->new("shell32","ShellExecute", "NPPPPI", "N");
    $_has_shellexecute = API_HAS_WIN32API if(defined($ShellExecute));
  }
}

######################################################################
# Private callback functions
######################################################################

######################################################################
# Private _mouse_move()
# MouseMove event hook handler for label
######################################################################
sub _mouse_move
{
  my ($self, $wparam, $lparam, $type, $msgcode) = @_;

  # Early version of Win32::GUI don't pass type and messagecode
  return if(defined($type) and $type != 0);
  return if(defined($msgcode) and $msgcode != WM_MOUSEMOVE);

  # safety check - this handler should never get called if GetCapture() is not available
  return if($_has_getcapture == API_NONE);

  my $cxM = $lparam & 0xFFFF;         # in client co-ordinates
  my $cyM = ($lparam >> 16) & 0xFFFF; # in client co-ordinates
  # If we have captured the mouse, they can be negative, so
  # convert to signed values
  if($cxM > 32767) { $cxM -= 65536; }
  if($cyM > 32767) { $cyM -= 65536; }

  my $hWnd = $self->{-handle};

  # Strategy:
  # While we're getting mouse events, the cursor is either in our window
  # or we have captured the mouse.
  # If we get mouse events, and we haven't got the capture, then the
  # mouse has moved into our window, so we change the font to underline
  # and set capture.
  # If we get mouse events and we have capture, then we check to see if
  # the mouse is over our control. If it is we do nothing;  If not,
  # then we relase capture and set the text back to normal

  # Based on ideas and code from:
  # http://www.codeguru.com/Cpp/controls/staticctrl/article.php/c5803/ 
  
  my $getcapture;
  $getcapture = Win32::GUI::GetCapture() if ($_has_getcapture & API_HAS_WIN32GUI);
  $getcapture = $GetCapture->Call()      if ($_has_getcapture & API_HAS_WIN32API);

  if($getcapture != $hWnd)
  {
    ### MouseIn
    # Set Mouse Capture to our window
    $self->SetCapture();

    # if we have an underlined font set it and force a redraw
    $self->SendMessage(WM_SETFONT, $self->{_hUfont}, 1) if($self->{_hUfont});

    # Call the MouseIn callback
    # NEM
    if( ref($self->{-onMouseIn}) eq 'CODE' ) {
      &{$self->{-onMouseIn}}($self, $cxM, $cyM);
    }
    # OEM
    if( $self->{-name} ) {
      my $callback = "main::" . $self->{-name} . "_MouseIn";
      if(defined(&$callback)) {
        my $ref = \&$callback;
        &{$ref}($self, $cxM, $cyM);
      }
    }
  } else {
    my ($clW, $ctW, $crW, $cbW) = $self->GetClientRect();

    # If pointer is not in window
    if ( ($cxM < $clW) || ($cxM > $crW) ||
         ($cyM < $ctW) || ($cyM > $cbW) )
    {
      ### onMouseOut
      # if we have a normal font, set it and force a redraw
      $self->SendMessage(WM_SETFONT, $self->{_hNfont}, 1) if($self->{_hNfont});

      # Call the onMouseOut callback
      # NEM
      if( ref($self->{-onMouseOut}) eq 'CODE' ) {
        &{$self->{-onMouseOut}}($self, $cxM, $cyM);
      }
      # OEM
      if( $self->{-name} ) {
        my $callback = "main::" . $self->{-name} . "_MouseOut";
        if(defined(&$callback)) {
          my $ref = \&$callback;
          &{$ref}($self, $cxM, $cyM);
        }
      }

      # Release capture
      $self->ReleaseCapture();
    }
  }

  return; # no return value, so not to affect normal operation
};

######################################################################
# Private _click()
# Left button down event hook handler for label
# processes Clicks on the label 
######################################################################
sub _click
{
  my ($self, $wparam, $lparam, $type, $msgcode) = @_;

  # Early version of Win32::GUI don't pass type and messagecode
  return if(defined($type) and $type != 0);
  return if(defined($msgcode) and $msgcode != WM_LBUTTONDOWN);

  $self->Launch();
  return; # no return value, so not to affect normal operation
};

=head1 METHODS

=cut

######################################################################
# Public new()
# constructor
######################################################################

=head2 new

  $hyperlink = Win32::GUI::HyperLink->new($parent, %options);

  $hyperlink = $window->AddHyperLink(%options);

Takes any options that L<Win32::GUI::Label> does with the following changes:

=over

=item B<-url>

The Link to launch. e.g. C<< -url => "http://www.perl.com/", >>
If not supplied will default to B<-text>.

=item B<-onMouseIn>

A code reference to call when the mouse moves over the link text.
Do not rely on this being available if your script is run on
a machine that has early versions of L<Win32::GUI> or does not have
L<Win32::API> available. See L</"REQUIRES"> for further information.

=item B<-onMouseOut>

A code reference to call when the mouse moves off the link text.
Do not rely on this being available if your script is run on
a machine that has early versions of L<Win32::GUI> or does not have
L<Win32::API> available. See L</"REQUIRES"> for further information.

=item B<-underline>

Controls how the text behaves as the mouse moves over and off the link text.
Possible values are: B<0> Text is not underlined. B<1> Text is underlined when
the mouse is over the link text.  This is the default.  B<2> Text is always
underlined.  On machines with early versions of L<Win32::GUI> or without
L<Win32::API> available option B<1> may be unavailable.  In this case
option B<2> becomes the default.  See L</"REQUIRES"> for further information.

=back

=head3 Differences to Win32::GUI::Label

If B<-text> is not supplied, then B<-text> defaults to B<-url>.
(If neither B<-url> nor B<-text> are supplied, then you have an empty label!)

B<-notify> is always set  to B<1>.

If a B<-onClick> handler is supplied, then the default action of launching
the link when the link is clicked is disabled.  See L</Launch> method
for how to get this functionality from you own Click handler.

=head3 Original/Old Event Model (OEM)

Win32::GUI::HyperLink will call the subroutines
C<< main::NAME_MouseIn >> and C<< main::NAME_MouseOut >>
, if they exist, when the mouse moves over the link,
and when the mouse moves out oif the link respectively, where NAME is
the name of the label, set with the B<-name> option.

=cut

sub new
{
  my $this = shift;
  my $class = ref($this) || $this;

  my $parentWin = shift;

  my %options = @_; # convert options to hash for easy manipulation;

  # somewhere to temporarily put options that we'll want
  # to store in the object once we have created it.
  my %storage;

  # Parse the options, and remove the non-standard Win32::GUI::Label
  # options (although I suspect that it wouldn't complain). Add defaults
  # for others if not provided
  
  #text and url
  $options{-url} = $options{-text} if not exists $options{-url};
  $options{-text} = $options{-url} if not exists $options{-text};
  if(exists $options{-url} ) {
    $storage{-url} = $options{-url};
    delete $options{-url};
  }
  $storage{-url} = "" if not defined $storage{-url};

  # colour
  $options{-foreground} = [0,0,255] if not exists $options{-foreground};  # default is blue

  # cursor
  if(not exists $options{-cursor} ) {
    # Try to load the window standard hand cursor,
    # if we can't get it for any reason, use our
    # own ... and if that fails for any reason, don't set one
    $options{-cursor} = Win32::GUI::LoadCursor(IDC_HAND) if ($_has_loadcursor & API_HAS_WIN32GUI);
    $options{-cursor} = $LoadCursor->Call(0,IDC_HAND)    if ($_has_loadcursor & API_HAS_WIN32API);
    if (not defined $options{-cursor}) {
      $options{-cursor} = _get_hand_cursor();
      # Store a reference to our Win32::GUI::Cursor in the hash
      # to prevent descruction: see notes below about doing the same
      # thing for the Win32::GUI::Font object.
      $storage{_alt_cursor_ref} = \$options{-cursor} if defined $options{-cursor};
    }
    delete $options{-cursor} if not defined $options{-cursor};
  }

  # underline style
  my $underline = UNDERLINE_HOVER;   # default is to underline when hovered over the link
  if(exists $options{-underline} ) {
    $underline = $options{-underline};
    delete $options{-underline};
  }
  # fallback to UNDERLINE_ALWAYS from UNDERLINE_HOVER if we can't do the mouse move handling
  $underline = UNDERLINE_ALWAYS if(($underline == UNDERLINE_HOVER) and ($_has_getcapture == API_NONE));

  # we need -notify, so set it
  $options{-notify} = 1;
  
  # onMouseIn/Out: remember onMouesIn and onMouseOut refernces
  # for us to call in our onMouseMove callback.
  if(exists $options{-onMouseIn} ) {
    $storage{-onMouseIn} = $options{-onMouseIn};
    delete $options{-onMouseIn};
  }
  if(exists $options{-onMouseOut} ) {
    $storage{-onMouseOut} = $options{-onMouseOut};
    delete $options{-onMouseOut};
  }

  ################################################
  # Call the parent constructor.
  # The return value is already a reference to 
  # a hash bless(ed) into the right class, so no
  # additional bless() is required.
  my $self = $class->SUPER::new($parentWin, %options);

  # Store additional data in the label object's hash so that we
  # have access to it in all callbacks
  foreach my $key (keys(%storage)) {
    $self->{$key} = $storage{$key};
  }

  # Set up our callbacks using Hook().  This done in preference to
  # using -onMouseMove and -onClick to allow it to work with both
  # OEM and NEM
  # Use WM_LBUTTONDOWN rather than NM_CLICK, as hooking WM_NOTIFY messages
  # is broken in Win32::GUI V1.0 and earlier
  $self->Hook(WM_LBUTTONDOWN, \&_click) if not exists $options{-onClick};
  $self->Hook(WM_MOUSEMOVE,   \&_mouse_move) if $_has_getcapture;

  # If underline == UNDERLINE_NONE(0) do nothing;
  # otherwise make a copy of the label font with underline
  # If underline == UNDERLINE_ALWAYS(2) set the label font to underlined
  # If underline == UNDERLINE_HOVER(1) put handles to both fonts into the
  # object hash, for use in the MouseMove hook
  if($underline != UNDERLINE_NONE) {
    my $hfont = $self->GetFont(); # handle to normal font
    my %fontOpts = Win32::GUI::Font::Info($hfont);
    $fontOpts{-underline} = 1;
    my $ufont = new Win32::GUI::Font (%fontOpts);
    if($underline == UNDERLINE_HOVER) {
      # Store the handles in the label hash for use in the callbacks
      $self->{_hNfont} = $hfont;
      $self->{_hUfont} = $ufont->{-handle};
    } elsif($underline == UNDERLINE_ALWAYS) {
      $self->SetFont($ufont);
    }
    # Store a reference to the new (underlined) font in the
    # label hash, to prevent it being destroyed before the
    # label.  Typically at the end of this
    # block, when $ufont goes out of scope, the perl GC would
    # call the Win32::GUI::Font DESTROY for the object, but
    # so long as the reference exists it will not get destroyed.
    # It will get destroyed when the last reference to this
    # HyperLink object is destroyed.
    $self->{_u_font_ref} = \$ufont;
  }

  return $self;
}

######################################################################
# Public Win32::GUI::Window::AddHyperLink()
# Alternate constructor in the Win32::GUI $window->AddXX style
######################################################################
sub Win32::GUI::Window::AddHyperLink
{
  return Win32::GUI::HyperLink->new(@_);
}

######################################################################
# Public Url()
######################################################################

=head2 Url

  $url = $hyperlink->Url();

Get the value of the current link.

  $hyperlink->Url($url);

Set the value of the current link.

=cut

sub Url
{
  $_[0]->{-url} = $_[1] if defined $_[1];
  return $_[0]->{-url};
}

######################################################################
# Public Launch()
######################################################################

=head2 Launch

  $hyperlink->Launch();

Launches the link url in the user's default browser. This method is supplied
to make it easy to call the default Click functionality from your
own Click Handler.  If you pass a C<-onClick> option to the constructor
then the default handler is disabled.  This allows you to turn off
the default click behaviour by passing a reference to an empty 
subroutine:

  -onClick => sub {},

If you have your own Click handler, then the default behaviour can be restored
by calling C<< $self->Launch() >> from within your handler.

Returns C<1> on Success, C<0> on failure (and C<carp>s a warning),
and C<undef> if there is no link url to try to launch.

C<< Launch() >> passes the value of the link url to the operating
system, which launches the link in the user's default browser.

If ShellExecute is available (L<Win32::GUI> greater than 1.0, or via
L<Win32::API>) then the link is passed to the Windows ShellExecute
function.  If not the link is passed to Windows C<< start(.exe) >>
command.  In either case any valid executable program
or document that has a file association should be successsfully
started.

=cut

sub Launch
{
  my $self = shift;
  my $retval = undef;

  # Only try to open the link if it is actually defined
  if($self->Url()) {
    $retval = 1;
    # Use ShellExecute if it is available else use system start ...
    if($_has_shellexecute) {
      my $exitval;
      $exitval = $self->ShellExecute("",$self->Url(),"","",SW_SHOWNORMAL) if ($_has_shellexecute & API_HAS_WIN32GUI);
      $exitval = $ShellExecute->Call($self->{-handle},"",$self->Url(),"","",SW_SHOWNORMAL) if ($_has_shellexecute & API_HAS_WIN32API);
      if ($exitval <= 32) {
        carp "Failed opening ".$self->Url()." ShellExecute($exitval) $^E";
        $retval = 0;
      }
    } else {
      my $exitval = system("start", $self->Url());
      if($exitval == -1 || $exitval) {
        carp "Failed opening ".$self->Url()." system(".($exitval>>8).") $^E";
        $retval = 0;
      }
    }
  }

  return $retval;
}

=head1 AUTHOR

Robert May, C<< <rmay@popeslane.clara.co.uk> >>

Additional information may be available at L<http://www.robmay.me.uk/win32gui/>.

=head1 REQUIRES

L<Win32::GUI> v0.99_1 or later.  The test suite passes at least as far back as
V0.0.670, and the code runs without errors, but differences in the event processing
loops means that the main functionality does not work.  If you need this
functionality with earlier versions of Win32::GUI it is suggested that you use
Win32::GUI::HyperLink v0.02.  If you make this code work with earlier versions
of Win32::GUI, please pass your changes back to the author for inclusion.

L<Win32::GUI::BitmapInline>, as distributed with Win32::GUI, will be used
if Win32::GUI::HyperLink cannot get the system's 'hand' cursor.
If Win32::GUI::BitmapInline is
not available in this circumctance, then the cursor will not change when
hovering over the link.

L<Win32::API>.  May be required for full functionality, depending on
your version of Win32::GUI.

If you do no have this module
installed then the dynamic underlining of the link as the mouse moves
over it may not work, and the MouseIn/Out events may not
be available.

As at L<Win32::GUI> 1.0 this module requires access to
LoadCursor, GetCapture and ShellExecute win32 API calls
that are not part of the Win32::GUI distribution.
API calls that are not available through
Win32::GUI are accessed using Win32::API, and if it is
not available, functionality will be missing:

LoadCursor: if not available then the default 'hand' cursor
that is used will be one built in to Win32::GUI::HyperLink
rather than the operating system's default.

GetCapture: if not available, then underlining of the link
text when the mouse hovers over the link is not available,
nor are the MouseIn or MouseOut events.

If you need the full functionality without using Win32::API
the the current CVS HEAD revision of the code has the
missing functions, and Win32::GUI::HyperLink is coded to use
them if they exist in the Win32::GUI build.

=head1 COMPATABILITY

This module should be backwards compatable with all prior
Win32::GUI::HyperLink releases, including the original
(v0.02) release.  If you find that it is not, please
inform the Author.

=head1 EXAMPLES

  use strict;
  use warnings;

  use Win32::GUI 1.0;
  use Win32::GUI::HyperLink;

  # A window
  my $win = Win32::GUI::Window->new(
    -title => "HyperLink",
    -pos => [ 100, 100 ],
    -size => [ 240, 200 ],
  );

  # Simplest usage
  $win->AddHyperLink(
    -text => "http://www.perl.org/",
    -pos => [10,10],
  );

  $win->Show();
  Win32::GUI::Dialog();
  exit(0);

=head1 BUGS

See the F<TODO> file from the disribution.

Please report any bugs or feature requests to the Author.

=head2 Bugs with the tests

All tests pass when run with 'prove'.  Some interaction with 'make test' results in the
following warnings, neither of which are cause for concern.

The test when neither B<-text> nor B<-url> are set when running C<03.method-new.t>
against Win32::GUI v1.0 results in a warning: C<< Use of uninitialized value in
subroutine entry at C:/Perl/site/lib/Win32/GUI.pm line 597, <DATA> line 164. >>.

C<99.pod-coverage.t> results in the warning:
C<< Too late to run INIT block at C:/Perl/site/lib/Win32/API/Type.pm line 71. >>

The tests do not cover any actual GUI interaction.

=head1 ACKNOWLEDGEMENTS

Many thanks to the Win32::GUI developers at
L<http://sourceforge.net/projects/perl-win32-gui/>

There was a previous incarnation of Win32::GUI::HyperLink that was posted
on win32-gui-users@lists.sourceforge.net in 2001.  I am not sure of the
original author but it looks like Aldo Calpini.

Some of the ideas here are taken from
L<http://www.codeguru.com/Cpp/controls/staticctrl/article.php/c5803/>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Robert May, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

######################################################################
# Private _get_hand_cursor()
# Alternative to the standard windows hand cursor, that we use if
# we don't have access to the windows one: It's not available on
# Win95; we may not have access to LoadCursor();
######################################################################
sub _get_hand_cursor
{
  # don't use Win32::GUI::Bitmap unless it is available
  BEGIN { eval "use Win32::GUI::BitmapInline 0.02"; };

  # if we already created a cursor object, then use it
  return $_hand_cursor if defined $_hand_cursor;

  return undef unless defined $Win32::GUI::BitmapInline::VERSION;

  $_hand_cursor = newCursor Win32::GUI::BitmapInline( q(
    AAACAAEAICAAAAUAAAAwAQAAFgAAACgAAAAgAAAAQAAAAAEAAQAAAAAAgAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAA////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    A/wAAAP8AAAH/gAAB/4AAA/+AAAP/wAAH/8AABf/AAA3/wAAd/8AAGf7AAAG2wAABtoAAAbYAAAG
    wAAABgAAAAYAAAAGAAAABgAAAAYAAAAAAAAA////////////////////////////////////////
    //////////////gB///4Af//+AH///AA///wAP//4AD//+AAf//AAH//wAB//4AAf/8AAH//AAB/
    /xAAf//wAP//8AH///AH///wP///8P////D////w////8P////n///8=
    ) );

  return $_hand_cursor;
}

1; # End of Win32::GUI::HyperLink

package Win32::GUI::HyperLink;
# $Id: Hyperlink.pm,v 1.3 2005/03/01 01:31:42 Robert May Exp $

use warnings;
use strict;
use Carp;

use Win32::GUI 1.0;  # May work with earlier versions, but I can't test.
                     # so make this a requirement for now.

use base qw(Win32::GUI::Label);

=head1 NAME

Win32::GUI::HyperLink - A Win32::GUI Hyperlink control

=cut

#our $VERSION = '0.11';
our $VERSION = sprintf("%d.%02d", q$Name: REL-0-12 $ =~ /(\d+)-(\d+)/, 999, 99);

=head1 SYNOPSIS

Win32::GUI::HyperLink is a Win32::GUI::Label that
acts as a clickable hyperlink.  By default
it has a 'hand' Cursor, is drawn in blue text rather than black and the
text is dynamically underlined when the mouse moves over the text.
 The Label can be
clicked to launch a hyperlink, and supports onMouseIN and onMouseOut
events to allow (for example) the link url to be displayed while the
mouse is over the link.

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
# Some useful constants from winuser.h (thanks to MinGW):
######################################################################
# Don't "use constant", as it fails with earlier versions of perl
sub IDC_HAND      () {32649};
sub WM_SETFONT    () {48};
sub SW_SHOWNORMAL () {1};

######################################################################
# The Win32::API calls we want to make:
######################################################################
# Dont load Win32::API unless it is available ...
BEGIN { eval "use Win32::API"; };

my $LoadCursor   = undef;
my $GetCapture   = undef;
my $ShellExecute = undef;
# if Win32::API is available
if (defined $Win32::API::VERSION) {
  # HCURSOR LoadCursor(HINSTANCE hInstance, LPCTSTR lpCursorName);
  $LoadCursor   = Win32::API->new('User32', 'LoadCursor', 'NN', 'N');
  # HWND GetCapture(VOID);
  $GetCapture   = Win32::API->new("User32","GetCapture", "", "N");
  # HINSTANCE ShellExecute(HWND hwnd, LPCTSTR lpOperation, LPCTSTR lpFile,
  #      LPCTSTR lpParameters, LPCTSTR lpDirectory, INT nShowCmd);
  $ShellExecute = Win32::API->new("shell32","ShellExecute", "NPPPPI", "N");
}

######################################################################
# package global storage
######################################################################
# If we create a cursor object, then store it here so that
# we only create one cursor object regardless of how many HyperLink
# objects we have.  See function _get_hand_cursor().
our $_hand_cursor = undef;

######################################################################
# Private callback functions
# By using references to anonymous subs we ensure no one
# can call these functions from outside the class
######################################################################

######################################################################
# Private sub_mouse_move()
# onMouseMove handler for label
######################################################################
my $sub_mouse_move = sub
{
  my $self = $_[0];
  my $cxM  = $_[1];
  my $cyM  = $_[2];

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
  
  if(defined $GetCapture) {
    if($GetCapture->Call() != $hWnd)
    {
      ### onMouseIn
      # if we have an underlined font set it and force a redraw
      Win32::GUI::SendMessage($hWnd, WM_SETFONT, $self->{_hUfont}, 1) if($self->{_hUfont});

      # Call the onMouseIn callback
      &{$self->{-onMouseIn}}(@_) if($self->{-onMouseIn});

      # Set Mouse Capture to our window
      $self->SetCapture();
    } else {
      my ($slW, $stW, $srW, $sbW) = $self->GetWindowRect();
      my ($clW, $ctW) = $self->ScreenToClient($slW, $stW);
      my ($crW, $cbW) = $self->ScreenToClient($srW, $sbW);

      # If pointer is not in window
      if ( ($cxM < $clW) || ($cxM > $crW) ||
           ($cyM < $ctW) || ($cyM > $cbW) )
      {
        ### onMouseOut
        # if we have a normal font, set it and force a redraw
        Win32::GUI::SendMessage($hWnd, WM_SETFONT, $self->{_hNfont}, 1) if($self->{_hNfont});

        # Call the onMouseOut callback
        &{$self->{-onMouseOut}}(@_) if($self->{-onMouseOut});

        # Release capture
        $self->ReleaseCapture();
      }
    }
  }

  # call the original onMouseMove function, if it exists
  return &{$self->{-onMouseMove}}(@_) if($self->{-onMouseMove});
  return 1;
};

######################################################################
# Private sub_click()
# Callback to process Click messages
######################################################################
my $sub_click = sub
{
  $_[0]->Launch();
  return 1;
};

=head1 METHODS

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
a machine that does not have L<Win32::API> available. See L</"REQUIRES">
for further information.

=item B<-onMouseOut>

A code reference to call when the mouse moves off the link text.
Do not rely on this being available if your script is run on
a machine that does not have L<Win32::API> available. See L</"REQUIRES">
for further information.

=item B<-underline>

Controls how the text behaves as the mouse moves over and off the link text.
Possible values are: B<0> Text is not underlined. B<1> Text is underlined when
the mouse is over the link text.  This is the default unless L<Win32::API>
is not available.
B<2> Text is always underlined.  This is the default if L<Win32::API> is not available.

=back

=head3 Differences to Win32::GUI::Label

If B<-text> is not supplied, then B<-text> defaults to B<-url>.
(If neither B<-url> nor B<-text> are supplied, then you have an empty label!)

B<-notify> is always set  to B<1>.

If a B<-onClick> handler is supplied, then the default action of launching
the link when the link is clicked is disabled.  See L</Launch> method
for how to get this functionality from you own Click handler.

Win32::GUI::HyperLink uses the NEM (New Event Model) to register for events with
the Win32::GUI::Label object. Hence if you want to get subroutines called by name (OEM),
then you must pass C<< -eventmodel => "both" >> as a parameter.

=cut

######################################################################
# Public new()
# constructor
######################################################################
sub new
{
  my $this = shift;
  my $class = ref($this) || $this;

  my $parentWin = shift;

  my %options = @_; # convert options to hash for easy manipulation;

  # somewhere to temporarily put options that we'll want
  # to store in the object once we have created it.
  my %storage;
  my $underline = 1;

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
    # Try to load the window standard cursor,
    # if we can't get it for any reason, use our
    # own ... and if that fails for any reason, don't set one
    $options{-cursor} = $LoadCursor->Call(0,IDC_HAND) if defined $LoadCursor;
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
  if(exists $options{-underline} ) {
    $underline = $options{-underline};
    delete $options{-underline};
  }

  # we need -notify, so set it
  $options{-notify} = 1;
  
  # onMouseMove: if the caller has set onMouseMove,
  # then store their code reference, and replace with our own.
  # we'll explicitly call their code from our callbacks.
  if(exists $options{-onMouseMove}) {
    $storage{-onMouseMove} = $options{-onMouseMove};
  }
  $options{-onMouseMove} = $sub_mouse_move;

  # onClick: If the user has set onClick then leave it and don't
  # add our callback.  If not then set ours ...
  $options{-onClick} = $sub_click if not exists $options{-onClick};

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

  # If underline == NEVER(0) do nothing;
  # otherwise make a copy of the label font with underline
  # If underline == ALWAYS(2) set the label font to underlined
  # If underline == HOVER(1) put handles to both fonts into the
  # object hash, for use in the onMouseMove callback
  if($underline) {
    my $hfont = $self->GetFont(); # handle to normal font
    my %fontOpts = Win32::GUI::Font::Info($hfont);
    $fontOpts{-underline} = 1;
    my $ufont = new Win32::GUI::Font (%fontOpts);
    if(defined($GetCapture) && $underline == 1) {
      # Store the handles in the label hash for use in the callbacks
      $self->{_hNfont} = $hfont;
      $self->{_hUfont} = $ufont->{-handle};
    } else { # Always underline
      $self->SetFont($ufont);
    }
    # Store a reference to the new (underlined) font in the
    # label hash, to prevent it being destroyed before the
    # label.  Typically at the end of this
    # block, when $ufont goes out of scope, the perl GC would
    # call the Win32::GUI::Font DESTRUCTOR for the object, but
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

=head2 Url

  $url = $hyperlink->Url();

Get the value of the current link.

  $hyperlink->Url($url);

Set the value of the current link.

=cut

######################################################################
# Public Url()
######################################################################
sub Url
{
  $_[0]->{-url} = $_[1] if defined $_[1];
  return $_[0]->{-url};
}

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

If L<Win32::API> is available
the link is passed to the Windows ShellExecute
function.  If not the link is passed to Windows
C<< start(.exe) >> command.  In either case any valid executable program
or document that has a file association should be successsfully
started.

=cut

######################################################################
# Public Launch()
######################################################################
sub Launch
{
  my $self = shift;
  my $retval = undef;

  # Only try to open the link if it is actually defined
  if($self->Url()) {
    $retval = 1;
    # Use ShellExecute if it is available else use system start ...
    if(defined $ShellExecute) {
      my $exitval = $ShellExecute->Call($self->{-handle},"",$self->Url(),"","",SW_SHOWNORMAL);
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

L<Win32::GUI> v1.0.  It may work with earlier versions, but this has
not been tested, and is not currently supported. It may be supported in future
releases, depending on feedback.  If you wish to try it with an earlier Win32::GUI version,
then you will need to remove the C<1.0> from the
C<use Win32::GUI 1.0> line of the code.  Please report any success or failure with
earlier versions to the Author.

L<Win32::GUI::BitmapInline>, as distributed with Win32::GUI, will be used
if Win32::GUI::HyperLink cannot get the system's 'hand' cursor.
If Win32::GUI::BitmapInline is
not available in this circumctance, then the cursor will not change when
hovering over the link.

L<Win32::API>.  May be required for full functionality, depending on
your version of Win32::GUI.  If you do no have this module
installed then the dynamic underlining of the link as the mouse moves
over it may not work, and the onMouseIn/Out event callbacks may not
be available.

This module requires access to some win32 API calls
that are not part of the current Win32::GUI
distribution.  Those functions that are not available through
Win32::GUI are accessed using Win32::API.  If Win32::API
is not available, and there is  not alternative
fallback strategy, then some functionality may be
missing. The test suite should warn if this affects you.

=head1 COMPATABILITY

This module should be backwards compatable
with the prior Win32::GUI::HyperLink module (v0.02).
If you find that it is not, please inform the Author.

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

If you want to use the OEM event model, then you must currently pass
C<< -eventmodel => "both" >> as an option to the constructor: as
Win32::GUI::HyperLink uses the NEM event model, this will be selected
by default.

See the F<TODO> file from the disribution.

Please report any bugs or feature requests to the Author.

=head2 Bugs with the tests

The test when neither B<-text> nor B<-url> are set results in a warning:
C<< Use of uninitialized value in subroutine entry at C:/Perl/site/lib/Win32/GUI.pm line 597, <DATA> line 164. >>
. I can't track this down, but it does not seem to be anything to worry about.

Some interaction with the test harness results in a warning
C<< Too late to run INIT block at C:/Perl/site/lib/Win32/API/Type.pm line 71. >>
when running the C<pod-coverage> tests. This also does not seem to be a problem.

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

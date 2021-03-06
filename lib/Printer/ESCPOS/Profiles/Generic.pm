use strict;
use warnings;

package Printer::ESCPOS::Profiles::Generic;

# PODNAME: Printer::ESCPOS::Profiles::Generic
# ABSTRACT: Generic Profile for Printers for L<Printer::ESCPOS>. Most common functions are included here.
# COPYRIGHT
# VERSION

# Dependencies
use 5.010;
use Moo;
with 'Printer::ESCPOS::Roles::Profile';

use constant {
    _ESC => "\x1b",
    _GS  => "\x1d",
    _DLE => "\x10",
    _FS  => "\x1c",
    # Level 2 Constants
    _FF   => "\x0c",
    _SP   => "\x20",
    _EOT  => "\x04",
    _DC4  => "\x14",
};

=method init

Initializes the Printer. Clears the data in print buffer and resets the printer to the mode that was in effect when the power was turned on. This function is automatically called on creation of printer object.

=cut

sub init {
    my ( $self ) = @_;

    $self->driver->print( _ESC . '@' );
}

=method enable 

Enables/Disables the printer with a '_ESC =' command (Set peripheral device). When disabled, the printer ignores all commands except enable() or other real-time commands.
Pass 1 to enable, pass 0 to disable
    
    $device->printer->enable(0) # disabled
    $device->printer->enable(1) # enabled

=cut

sub enable {
    my ( $self, $n ) = @_;

    if ( $n == 1 ) {
        $self->driver->print( _ESC . '=' . chr(1) );
    } else {
        $self->driver->print( _ESC . '=' . chr(2) );
    }
}

=method printAreaWidth

Sets the Print area width specified by nL and NH. The width is calculated as 
    ( nL + nH * 256 ) * horiz_motion_unit 
    
A pre-requisite line feed is automatically executed before printAreaWidth method.

    $device->printer->printAreaWidth( nL => 0, nH =>0 );

=cut

sub printAreaWidth {
    my ( $self, %params ) = @_;
    $params{nL} = defined $params{nL} ? $params{nL} : 65;
    $params{nH} = defined $params{nH} ? $params{nH} : 2;

    $self->lf();
    $self->driver->write( _GS . 'W' . chr( $params{nL} ) . chr( $params{nH} ) );
}

=method tabPositions

Sets horizontal tab positions for tab stops. Upto 32 tab positions can be set in most receipt printers.

    $device->printer->tabPositions( 5, 9, 13 );

* Default tab positions are usually in intervals of 8 chars (9, 17, 25) etc.

=cut

sub tabPositions {
    my ( $self, @positions ) = @_;
    my $pos = '';

    $pos .= chr( $_ ) for @positions;
    $self->driver->write( _ESC . 'D' . $pos . chr(0) );
}

=method tab 

moves the cursor to next horizontal tab position like a "\t". This command is ignored unless the next horizontal tab position has been set. You may substitute this command with a "\t" as well.

This

    $device->printer->text("blah blah");
    $device->printer->tab();
    $device->printer->text("blah2 blah2");

is same as this

    $device->printer->text("blah blah\tblah2 blah2");

=cut

sub tab {
    my ( $self ) = @_;

    $self->driver->write( "\t" );
}

=method lf

line feed. Moves to the next line. You can substitute this method with {"\n"} in your print or write method e.g. :

This

    $device->printer->text("blah blah");
    $device->printer->lf();
    $device->printer->text("blah2 blah2");

is same as this

    $device->printer->text("blah blah\nblah2 blah2");

=cut

sub lf {
    my ( $self ) = @_;

    $self->driver->write( "\n" );
}

=method ff

When in page mode, print data in the buffer and return back to standard mode

=cut

sub ff {
    my ( $self ) = @_;

    $self->driver->write( "\x0c" );
}

=method cr

Print and carriage return

When automatic line feed is enabled this method works the same as lf , else it is ignored.

=cut

sub cr {
    my ( $self ) = @_;

    $self->driver->write( "\x0d" );
}

=method cancel

Cancel (delete) page data in page mode

=cut

sub cancel {
    my ( $self ) = @_;

    $self->driver->write( "\x18" );
}

=method font

Set Font style, you can pass *a*, *b* or *c*. Many printers don't support style *c* and only have two supported styles.

    $device->printer->font('a');
    $device->printer->text('Writing in Font A');
    $device->printer->font('b');
    $device->printer->text('Writing in Font B');

=cut

sub font {
    my ( $self, $font ) = @_;

    $self->fontStyle( $font );
    if( $self->usePrintMode && $font ne 'c') {
        $self->_updatePrintMode;
    } else {
        my %fontMap = (
            a => "\x00",
            b => "\x01",
            c => "\x02",
        );

        $self->driver->write( _ESC . 'M' . $fontMap{$font});
    }
}

=method bold 

Set bold mode *0* for off and *1* for on. Also called emphasized mode in some printer manuals 

    $device->printer->bold(1);
    $device->printer->text("This is Bold Text\n");
    $device->printer->bold(0);
    $device->printer->text("This is not Bold Text\n");

=cut

sub bold {
    my ( $self, $emphasized ) = @_;

    $self->emphasizedStatus( $emphasized );
    if( $self->usePrintMode ) {
        $self->_updatePrintMode;
    } else {
        $self->driver->write( _ESC . 'E' . int( $emphasized ) );
    }
}

=method doubleStrike 

Set double-strike mode *0* for off and *1* for on

    $device->printer->doubleStrike(1);
    $device->printer->text("This is Double Striked Text\n");
    $device->printer->doubleStrike(0);
    $device->printer->text("This is not Double Striked  Text\n");

=cut

sub doubleStrike {
    my ( $self, $flag ) = @_;

    $self->driver->write( _ESC . 'G' . int( $flag ) );
}

=method underline

set underline, *0* for off, *1* for on and *2* for double thickness 

    $device->printer->underline(1);
    $device->printer->text("This is Underlined Text\n");
    $device->printer->underline(2);
    $device->printer->text("This is Underlined Text with thicker underline\n");
    $device->printer->underline(0);
    $device->printer->text("This is not Underlined Text\n");

=cut

sub underline {
    my ( $self, $underline ) = @_;

    $self->underlineStatus($underline);
    if( $self->usePrintMode ) {
        $self->_updatePrintMode;
    } else {
        $self->driver->write( _ESC . '-' . $underline );
    }
}

=method invert

Reverse white/black printing mode pass *0* for off and *1* for on

    $device->printer->invert(1);
    $device->printer->text("This is Inverted Text\n");
    $device->printer->invert(0);
    $device->printer->text("This is not Inverted Text\n");

=cut

sub invert {
    my ( $self, $invert ) = @_;
    $self->driver->write( _GS . 'B' . chr( $invert ) );
}

=method color

Most thermal printers support just one color, black. Some ESCPOS printers(especially dot matrix) also support a second color, usually red. In many models, this only works when the color is set at the beginning of a new line before any text is printed. Pass *0* or *1* to switch between the two colors.

    $device->printer->lf();
    $device->printer->color(0); #black
    $device->printer->text("black"); 
    $device->printer->lf();
    $device->printer->color(1); #red
    $device->printer->text("Red"); 
    $device->printer->print();


=cut

sub color {
    my ( $self, $color ) = @_;

    $self->driver->write( _ESC . 'r' . chr( $color ) );
}

=method justify 

Set Justification. Options *left*, *right* and *center*

    $device->printer->justify( 'right' );
    $device->printer->text("This is right justified"); 

=cut

sub justify {
    my ( $self, $j ) = @_;

    my %jmap = (
        left   => 0,
        center => 1,
        right  => 2,
    );
    $self->lf();
    $self->driver->write( _ESC . 'a' . int( $jmap{lc $j} ) );
}

=method upsideDown

Sets Upside Down Printing on/off (pass *0* or *1*)

    $device->printer->upsideDownPrinting(1);
    $device->printer->text("This text is upside down"); 

=cut

sub upsideDown {
    my ( $self, $flag ) = @_;

    $self->lf();
    $self->driver->write( _ESC . '{' . int( $flag ) );
}

=method fontHeight 

Set font height. Only supports *0* or *1* for printmode set to 1, supports values *0*, *1*, *2*, *3*, *4*, *5*, *6* and *7* for non-printmode state (default) 

    $device->printer->fontHeight(1);
    $device->printer->text("double height\n");
    $device->printer->fontHeight(2);
    $device->printer->text("triple height\n");
    $device->printer->fontHeight(3);
    $device->printer->text("quadruple height\n");
    . . .

=cut

sub fontHeight {
    my ( $self, $height ) = @_;
    my $width = $self->widthStatus;

    $self->heightStatus( $height );
    if( $self->usePrintMode ) {
        $self->_updatePrintMode;
    } else {
        $self->driver->write( _GS . '!' . chr( $width << 4 | $height ));
    }
}

=method fontWidth 

Set font width. Only supports *0* or *1* for printmode set to 1, supports values *0*, *1*, *2*, *3*, *4*, *5*, *6* and *7* for non-printmode state (default) 

    $device->printer->fontWidth(1);
    $device->printer->text("double width\n");
    $device->printer->fontWidth(2);
    $device->printer->text("triple width\n");
    $device->printer->fontWidth(3);
    $device->printer->text("quadruple width\n");
    . . .

=cut

sub fontWidth {
    my ( $self, $width ) = @_;
    my $height = $self->heightStatus;

    $self->widthStatus( $width );
    if( $self->usePrintMode ) {
        $self->_updatePrintMode;
    } else {
        $self->driver->write( _GS . '!' . chr( int( $width ) << 4 | int( $height ) ));
    }
}

=method charSpacing

Sets character spacing takes a value between 0 and 255

    $device->printer->charSpacing(5);
    $device->printer->text("Blah Blah Blah\n");
    $device->printer->print();

=cut

sub charSpacing {
    my ( $self, $spacing ) = @_;
    $self->driver->write( _ESC . _SP . chr( $spacing ) );
}

=method lineSpacing 

Sets the line spacing i.e the spacing between each line of printout.

    $device->printer->lineSpacing($spacing);

* 0 <= $spacing <= 255

=cut

sub lineSpacing {
    my ( $self, $spacing ) = @_;
    $self->driver->write( _ESC . '3' . chr( $spacing ) );
}

=method selectDefaultLineSpacing 

Reverts to default line spacing for the printer

    $device->printer->selectDefaultLineSpacing();

=cut

sub selectDefaultLineSpacing {
    my ( $self ) = @_;
    $self->driver->write( _ESC . '2' );
}

=method printPosition

Sets the distance from the beginning of the line to the position at which characters are to be printed.

    $device->printer->printPosition( $length, $height );

* 0 <= $length <= 255
* 0 <= $height <= 255

=cut

sub printPosition {
    my ( $self, $length, $height ) = @_;
    $self->driver->write( _ESC . '$' . chr( $length )  . chr( $height ) );
}

=method leftMargin

Sets the left margin. Takes two single byte parameters, ~nL~ and ~nH~.

To determine the value of these two bytes, use the INT and MOD conventions. INT indicates the integer (or whole number) part of a number, while MOD indicates the remainder of a division operation. Must be sent before a new line begins to be effective.

For example, to break the value 520 into two bytes, use the following two equations:
~nH~ = INT 520/256
~nL~ = MOD 520/256

    $device->printer->leftMargin(nL => $nl, nH => $nh);

=cut

sub leftMargin {
    my ( $self, %params ) = @_;

    $self->driver->write( _GS . 'L' . chr( $params{nL} ) . chr( $params{nH} ) );
}

=method rot90

Rotate printout by 90 degrees

    $device->printer->rot90(1);
    $device->printer->text("This is rotated 90 degrees\n");
    $device->printer->rot90(0);
    $device->printer->text("This is not rotated 90 degrees\n");

=cut

sub rot90 {
    my ( $self, $rot ) = @_;

    $self->driver->write( _ESC . 'V' . chr( $rot ) );
}

# This is a redundant function in ESCPOS which updates the printer
sub _updatePrintMode {
    my ( $self ) = @_;
    my %fontMap = (
        a => 0,
        b => 1,
    );

    my $value = $fontMap{ $self->fontStyle }
    . '00' 
    . $self->emphasizedStatus
    . ( $self->heightStatus?'1':'0' )
    . ( $self->widthStatus?'1':'0' )
    . '0'
    . $self->underlineStatus;
    $self->driver->write( _ESC . '!' . pack( "b*", $value ) );
}

# BEGIN: BARCODE functions

=method barcode

This method prints a barcode to the printer. This can be bundled with other text formatting commands at the appropriate point where you would like to print a barcode on your print out. takes argument ~barcode~ as the barcode value.

In the simplest form you can use this command as follows:

    #Default barcode printed in code93 system with a width of 2 and HRI Chars printed below the barcode
    $device->printer->barcode(
        barcode     => 'SHANTANU BHADORIA',
    );

However there are several customizations available including barcode ~system~, ~font~, ~height~ etc.

    my $hripos = 'above';
    my $font   = 'a';
    my $height = 100;
    my $system = 'UPC-A';
    $device->printer->barcode(
        HRIPosition => $hripos,        # Position of Human Readable characters
                                       # 'none','above','below','aboveandbelow'
        font        => $font,          # Font for HRI characters. 'a' or 'b'
        height      => $height,        # no of dots in vertical direction
        system      => $system,        # Barcode system
        width       => 2               # 2:0.25mm, 3:0.375mm, 4:0.5mm, 5:0.625mm, 6:0.75mm
        barcode     => '123456789012', # Check barcode system you are using for allowed 
                                       # characters in barcode
    );
    $device->printer->barcode(
        system      => 'CODE39',
        HRIPosition => 'above',
        barcode     => '*1-I.I/ $IA*',
    );
    $device->printer->barcode(
        system      => 'CODE93',
        HRIPosition => 'above',
        barcode     => 'Shan',
    );

Available barcode ~systems~:

* UPC-A
* UPC-C
* JAN13
* JAN8
* CODE39
* ITF
* CODABAR
* CODE93  
* CODE128 

=cut

sub barcode {
    my ( $self, %params ) = @_;

    my %map = (
        none          => 0,
        above         => 1,
        below         => 2,
        aboveandbelow => 3,
    );
    $self->driver->write( _GS . 'H' . chr(
            $map{$params{HRIPosition} || 'below'}
        ) );

    %map = (
        a => 0,
        b => 1,
    );
    $self->driver->write( _GS . 'f' . chr(
            $map{$params{font} || 'b'}
        ) );

    $self->driver->write( _GS . 'h' . chr(
            $params{height} || 50 
        ) );

    $self->driver->write( _GS . 'w' . chr(
            $params{width} || 2 
        ) );
  
    %map = (
        'UPC-A' => 0,
        'UPC-B' => 1,
        JAN13   => 2,
        JAN8    => 3,
        CODE39  => 4,
        ITF     => 5,
        CODABAR => 6,
        CODE93  => 7,
        CODE128 => 8,
    );
    $params{system} ||= 'CODE93';

    if(
        $map{$params{system}} < 9
    ) {
        $self->driver->write( _GS . 'k' 
            . chr( $map{$params{system}} + 65 )
            . chr( length $params{barcode} )
            . $params{barcode}
        );
    } else {
        die "Invalid system in barcode";
    }
}

# END: BARCODE functions

# BEGIN: Bitmap printing methods

=method printNVImage

Prints bit image stored in Non-Volatile (NV) memory of the printer. 

    $device->printer->printNVImage($flag);

* $flag = 0 # Normal width and Normal Height
* $flag = 1 # Double width and Normal Height
* $flag = 2 # Normal width and Double Height
* $flag = 3 # Double width and Double Height

=cut

sub printNVImage {
    my ( $self, $flag ) = @_;

    $self->driver->write( _FS . 'p' . chr(1) . chr($flag) );
}

=method printImage

Prints bit image stored in Volatile memory of the printer. This image gets erased when printer is reset. 

    $device->printer->printImage($flag);

* $flag = 0 # Normal width and Normal Height
* $flag = 1 # Double width and Normal Height
* $flag = 2 # Normal width and Double Height
* $flag = 3 # Double width and Double Height

=cut

sub printImage {
    my ( $self, $flag ) = @_;

    $self->driver->write( _GS . '/' . chr($flag) );
}

# END: Bitmap printing methods 

# BEGIN: Peripheral and cutter Control Commands

=method cutPaper

Cuts the paper, if ~feed~ is set to *0* then printer doesnt feed paper to cutting position before cutting it. The default behavior is that the printer doesn't feed paper to cutting position before cutting. One pre-requisite line feed is automatically executed before paper cut though.

    $device->printer->cutPaper( feed => 0 )

While not strictly a text formatting option, in receipt printer the cut paper instruction is sent along with the rest of the text and text formatting data and the printer cuts the paper at the appropriate points wherever this command is used.

=cut

sub cutPaper {
    my ( $self, %params ) = @_;
    $params{feed} = defined $params{feed} ? $params{feed} : 0;

    $self->lf();
    if( $params{feed} == 0 ) {
        $self->driver->write( _GS . 'V' . chr(1));
    } else {
        $self->driver->write( _GS . 'V' . chr(66) . chr(0) );
    }

}

=method drawerKickPulse

Trigger drawer kick. Used to open cash drawer connected to the printer. In some use cases it may be used to trigger other devices by close contact.

    $device->printer->drawerKickPulse( $pin, $time );

* $pin is either 0( for pin 2 ) and 1( for pin5 ) default value is 0
* $time is a value between 1 to 8 and the pulse duration in multiples of 100ms. default value is 8

For default values use without any params to kick drawer pin 2 with a 800ms pulse

    $device->printer->drawerKickPulse();

Again like cutPaper command this is obviously not a text formatting command but this command is sent along with the rest of the text and text formatting data and the printer sends the pulse at the appropriate points wherever this command is used. While originally designed for triggering a cash drawer to open, in practice this port can be used for all sorts of devices like pulsing light, or sound alarm etc.

=cut

sub drawerKickPulse {
    my ( $self, $pin, $time ) = @_;
    $pin  = defined $pin ? $pin : 0;
    $time = defined $time ? $time : 8;

    $self->driver->write( _DLE . _DC4 . "\x01" . chr( $pin )  . chr( $time ) );
}

# End Peripheral Control Commands

# BEGIN: Printer STATUS methods 

=method printerStatus

Returns printer status in a hashref.

    return {
        drawer_pin3_high            => $flags[5],
        offline                     => $flags[4],
        waiting_for_online_recovery => $flags[2],
        feed_button_pressed         => $flags[1],
    };

=cut

sub printerStatus {
    my ( $self ) = @_;
    
    my @flags = split(
        //,
        unpack( "B*", $self->driver->read( _DLE . _EOT . "\x01", 255 ) )
    );
    return {
        drawer_pin3_high            => $flags[5],
        offline                     => $flags[4],
        waiting_for_online_recovery => $flags[2],
        feed_button_pressed         => $flags[1],
    };
}

=method offlineStatus

Returns a hashref for paper cover closed status, feed button pressed status, paper end stop status, and a aggregate error status either of which will prevent the printer from processing a printing request.

    return {
        cover_is_closed     => $flags[5],
        feed_button_pressed => $flags[4],
        paper_end           => $flags[2],
        error               => $flags[1],
    };

=cut

sub offlineStatus {
    my ( $self ) = @_;
    
    my @flags = split(
        //,
        unpack( "B*", $self->driver->read( _DLE . _EOT . "\x02", 255 ) )
    );
    return {
        cover_is_closed     => $flags[5],
        feed_button_pressed => $flags[4],
        paper_end           => $flags[2],
        error               => $flags[1],
    };
}

=method errorStatus

Returns hashref with error flags for auto_cutter_error, unrecoverable error and auto-recoverable error

    return {
        auto_cutter_error     => $flags[4],
        unrecoverable_error   => $flags[2],
        autorecoverable_error => $flags[1],
    };

=cut

sub errorStatus {
    my ( $self ) = @_;
    
    my @flags = split(
        //,
        unpack( "B*", $self->driver->read( _DLE . _EOT . "\x03", 255 ) )
    );
    return {
        auto_cutter_error     => $flags[4],
        unrecoverable_error   => $flags[2],
        autorecoverable_error => $flags[1],
    };
}

=method paperSensorStatus

Gets printer paper Sensor status. Returns a hashref with four sensor statuses. Two paper near end sensors and two paper end sensors for printers supporting this feature. The exact returned status might differ based on the make of your printer. If any of the flags is set to 1 it implies that the paper is out or near end.

    return {
        paper_roll_near_end_sensor_1 => $flags[5],
        paper_roll_near_end_sensor_2 => $flags[4],
        paper_roll_status_sensor_1 => $flags[2],
        paper_roll_status_sensor_2 => $flags[1],
    };

=cut

sub paperSensorStatus {
    my ( $self ) = @_;
    
    my @flags = split(
        //,
        unpack( "B*", $self->driver->read( _DLE . _EOT . "\x04", 255 ) )
    );
    return {
        paper_roll_near_end_sensor_1 => $flags[5],
        paper_roll_near_end_sensor_2 => $flags[4],
        paper_roll_status_sensor_1 => $flags[2],
        paper_roll_status_sensor_2 => $flags[1],
    };
}

=method inkStatusA

Only available for dot-matrix and other ink consuming printers. Gets printer ink status for inkA(usually black ink). Returns a hashref with ink statuses.

    return {
        ink_near_end          => $flags[5],
        ink_end               => $flags[4],
        ink_cartridge_missing => $flags[2],
        cleaning_in_progress  => $flags[1],
    };

=cut

sub inkStatusA {
    my ( $self ) = @_;
    
    my @flags = split(
        //,
        unpack( "B*", $self->driver->read( _DLE . _EOT . "\x07" . "\x01", 255 ) )
    );
    return {
        ink_near_end          => $flags[5],
        ink_end               => $flags[4],
        ink_cartridge_missing => $flags[2],
        cleaning_in_progress  => $flags[1],
    };
}

=method inkStatusB

Only available for dot-matrix and other ink consuming printers. Gets printer ink status for inkB(usually red ink). Returns a hashref with ink statuses.

    return {
        ink_near_end          => $flags[5],
        ink_end               => $flags[4],
        ink_cartridge_missing => $flags[2],
    };

=cut

sub inkStatusB {
    my ( $self ) = @_;
    
    my @flags = split(
        //,
        unpack( "B*", $self->driver->read( _DLE . _EOT . "\x07" . "\x02", 255 ) )
    );
    return {
        ink_near_end          => $flags[5],
        ink_end               => $flags[4],
        ink_cartridge_missing => $flags[2],
    };
}

# END: Printer STATUS methods 

no Moo;
__PACKAGE__->meta->make_immutable;

1;

package Printer::ESCPOS::Profiles::Generic;

# PODNAME: Printer::ESCPOS::Profiles::Generic
# ABSTRACT: Generic Profile for Printers for Printer::ESCPOS. Most common functions are included here.
# COPYRIGHT
# VERSION

# Dependencies
use 5.010;
use Moose;
with 'Printer::ESCPOS::Roles::Profile';
use namespace::autoclean;

use Printer::ESCPOS::Constants;

use constant {
    ESC => "\x1b",
    GS  => "\x1d",
    DLE => "\x10",
    FS  => "\x1c",
    # Level 2 Constants
    FF   => "\x0c",
    SP   => "\x20",
    EOT  => "\x04",
    DC4  => "\x14",
    NULL => "\x00",
};

=method init

Initializes the Printer. Clears the data in print buffer and resets the printer to the mode that was in effect when the power was turned on.

=cut

sub init {
    my ( $self ) = @_;

    $self->driver->write( ESC . '@' );
}

=method enable 

Enables/Disables the printer with a 'ESC =' command (Set peripheral device). When disabled, the printer ignores all commands except enable() or other real-time commands
pass 1 to enable, pass 0 to disable
    
    $device->printer->enable(0) # disabled
    $device->printer->enable(1) # enabled

=cut

sub enable {
    my ( $self, $n ) = @_;

    if ( $n == 1 ) {
        $self->driver->write( ESC . '=' . chr(1) );
    } else {
        $self->driver->write( ESC . '=' . chr(2) );
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

    say $params{nL};
    say $params{nH};

    $self->lf();
    $self->driver->write( GS . 'W' . chr( $params{nL} ) . chr( $params{nH} ) );
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
    $self->driver->write( ESC . 'D' . $pos . NULL );
}

=method tab 

moves the cursor to next horizontal tab position like a "\t". This command is ignored unless the next horizontal tab position has been set.

=cut

sub tab {
    my ( $self ) = @_;

    $self->driver->write( "\x09" );
}

=method lf

line feed. This method will most likely not be used since you can simply insert a \n in your print string for write function to substitute for this function e.g. :

This

    $device->printer->write("blah blah");
    $device->printer->lf();
    $device->printer->write("blah2 blah2");

is same as this

    $device->printer->write("blah blah\nblah2 blah2");

=cut

sub lf {
    my ( $self ) = @_;

    $self->driver->write( "\x0a" );
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

=method can

Cancel (delete) page data in page mode

=cut

sub cancel {
    my ( $self ) = @_;

    $self->driver->write( "\x18" );
}

=method font

Set Font style, you can pass 'a', 'b' or 'c'. Many printers don't support style 'c' and only have two supported styles.

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

        $self->driver->write( ESC . 'M' . $fontMap{$font});
    }
}

=method emphasized

Set emphasized mode 0 for off and 1 for on

=cut

sub emphasized {
    my ( $self, $emphasized ) = @_;

    $self->emphasizedStatus( $emphasized );
    if( $self->usePrintMode ) {
        $self->_updatePrintMode;
    } else {
        $self->driver->write( ESC . 'E' . int( $emphasized ) );
    }
}

=method doubleStrike 

Set double-strike mode 0 for off and 1 for on

=cut

sub doubleStrike {
    my ( $self, $flag ) = @_;

    $self->driver->write( ESC . 'G' . int( $flag ) );
}

=method justification 

Set Justification. Options 'left', 'right' and 'center'

    $self->printer->justification('right');

=cut

sub justification {
    my ( $self, $j ) = @_;

    my %jmap = (
        left   => 0,
        center => 1,
        right  => 2,
    );
    $self->lf();
    $self->driver->write( ESC . 'a' . int( $jmap{lc $j} ) );
}

=method upsideDown

Sets Upside Down Printing on/off (pass 0 or 1)

    $self->printer->upsideDownPrinting(1);

=cut

sub upsideDown {
    my ( $self, $flag ) = @_;

    $self->lf();
    $self->driver->write( ESC . '{' . int( $flag ) );
}

=method height 

Set font height. Only supports 0 or 1 for printmode set to 1, supports values 0 to 7 for non-printmode state (default) 

=cut

sub height {
    my ( $self, $height ) = @_;
    my $width = $self->widthStatus;

    $self->heightStatus( $height );
    if( $self->usePrintMode ) {
        $self->_updatePrintMode;
    } else {
        $self->driver->write( GS . '!' . chr( $width << 4 | $height ));
    }
}

=method width 

Set font height. Only supports 0 or 1 for printmode set to 1, supports values 0 to 7 for non-printmode state (default) 

=cut

sub width {
    my ( $self, $width ) = @_;
    my $height = $self->heightStatus;

    $self->widthStatus( $width );
    if( $self->usePrintMode ) {
        $self->_updatePrintMode;
    } else {
        $self->driver->write( GS . '!' . chr( int( $width ) << 4 | int( $height ) ));
    }
}

=method underline

set underline, 0 for off, 1 for on and 2 for double thickness 

=cut

sub underline {
    my ( $self, $underline ) = @_;

    $self->underlineStatus($underline);
    if( $self->usePrintMode ) {
        $self->_updatePrintMode;
    } else {
        $self->driver->write( ESC . '-' . $underline );
    }
}

=method invert

Reverse white/black printing mode pass 0 for off and 1 for on

    $device->printer->invert(0);

=cut

sub invert {
    my ( $self, $invert ) = @_;
    $self->driver->write( GS . 'B' . chr( $invert ) );
}

=method charSpacing

Sets charachter spacing takes a value between 0 and 255

    $device->printer->charSpacing(5);
    $device->printer->write("Blah Blah Blah\n");
    $device->printer->print();

=cut

sub charSpacing {
    my ( $self, $spacing ) = @_;
    $self->driver->write( ESC . SP . chr( $spacing ) );
}

=method lineSpacing 

    $device->printer->lineSpacing($spacing)

* 0 <= spacing <= 255

=cut

sub lineSpacing {
    my ( $self, $spacing ) = @_;
    $self->driver->write( ESC . '3' . chr( $spacing ) );
}

=method selectDefaultLineSpacing 

Revert to default Line spacing for the printer

=cut

sub selectDefaultLineSpacing {
    my ( $self ) = @_;
    $self->driver->write( ESC . '2' );
}

=method printPosition

Sets the distance from the beginning of the line to the position at which characters are to be printed.
    $device->printer->printPosition( $length, $height );

* 0 <= $length <= 255
* 0 <= $height <= 255

=cut

sub printPosition {
    my ( $self, $length, $height ) = @_;
    $self->driver->write( ESC . '$' . chr( $length )  . chr( $height ) );
}

=method drawerKickPulse

Trigger drawer kick

    $device->printer->drawerKickPulse( $pin, $time );

* $pin is either 0( for pin 2 ) and 1( for pin5 ) default value is 0
* $time is a value between 1 to 8 and the pulse duration in multiples of 100ms. default value is 8

For default values use without any params to kick drawer pin 2 with a 800ms pulse

    $device->printer->drawerKickPulse();

=cut

sub drawerKickPulse {
    my ( $self, $pin, $time ) = @_;
    $pin  = defined $pin ? $pin : 0;
    $time = defined $time ? $time : 8;

    $self->driver->write( DLE . DC4 . "\x01" . chr( $pin )  . chr( $time ) );
}

=method cutPaper

Cuts the paper, if feed is set to 0 then printer doesnt feed paper to cutting position before cutting it. The default behavior is that the printer doesn't feed paper to cutting position before cutting. One pre-requisite line feed is automatically executed before paper cut.

    $device->printer->cutPaper( feed => false )

=cut

sub cutPaper {
    my ( $self, %params ) = @_;
    $params{feed} = defined $params{feed} ? $params{feed} : 0;

    $self->lf();
    if( $params{feed} == 0 ) {
        $self->driver->write( GS . 'V' . chr(1));
    } else {
        $self->driver->write( GS . 'V' . chr(66) . chr(0) );
    }

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
    $self->driver->write( ESC . '!' . pack( "b*", $value ) );
}

# BEGIN: Bitmap printing methods

=method printNVImage

Prints bit image stored in Non-Volatile (NV) memory of the printer. 
This function also writes the buffer data to the printer before printing the bit image. 

    $self->printer->printNVImage($flag);

* $flag = 0 # Normal width and Normal Height
* $flag = 1 # Double width and Normal Height
* $flag = 2 # Normal width and Double Height
* $flag = 3 # Double width and Double Height

=cut

sub printNVImage {
    my ( $self, $flag ) = @_;

    $self->driver->write( FS . 'p' . chr(1) . chr($flag) );
}

=method printImage

Prints bit image stored in Volatile memory of the printer. This image gets erased when printer is reset. 
This function also writes the buffer data to the printer before printing the bit image. 

    $self->printer->printImage($flag);

* $flag = 0 # Normal width and Normal Height
* $flag = 1 # Double width and Normal Height
* $flag = 2 # Normal width and Double Height
* $flag = 3 # Double width and Double Height

=cut

sub printImage {
    my ( $self, $flag ) = @_;

    $self->driver->write( GS . '/' . chr($flag) );
}

# END: Bitmap printing methods 

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
        unpack( "B*", $self->driver->read( DLE . EOT . "\x01", 255 ) )
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
        unpack( "B*", $self->driver->read( DLE . EOT . "\x02", 255 ) )
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
        unpack( "B*", $self->driver->read( DLE . EOT . "\x03", 255 ) )
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
        unpack( "B*", $self->driver->read( DLE . EOT . "\x04", 255 ) )
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
        unpack( "B*", $self->driver->read( DLE . EOT . "\x07" . "\x01", 255 ) )
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
        unpack( "B*", $self->driver->read( DLE . EOT . "\x07" . "\x02", 255 ) )
    );
    return {
        ink_near_end          => $flags[5],
        ink_end               => $flags[4],
        ink_cartridge_missing => $flags[2],
    };
}

# END: Printer STATUS methods 

# BEGIN: BARCODE functions

=method barcode

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
        barcode     => '123456789012', # Check barcode systems for allowed value
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

    #Default barcode printed in code93 width 2 and HRI Chars below the barcode
    $device->printer->barcode(
        barcode     => 'SHANTANU BHADORIA',
    );

Available systems:

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
    $self->driver->write( GS . 'H' . chr(
            $map{$params{HRIPosition} || 'below'}
        ) );

    %map = (
        a => 0,
        b => 1,
    );
    $self->driver->write( GS . 'f' . chr(
            $map{$params{font} || 'b'}
        ) );

    $self->driver->write( GS . 'h' . chr(
            $params{height} || 50 
        ) );

    $self->driver->write( GS . 'w' . chr(
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
        $self->driver->write( GS . 'k' 
            . chr( $map{$params{system}} + 65 )
            . chr( length $params{barcode} )
            . $params{barcode}
        );
    } else {
        die "Invalid system in barcode";
    }
}

# END: BARCODE functions

no Moose;
__PACKAGE__->meta->make_immutable;

1;

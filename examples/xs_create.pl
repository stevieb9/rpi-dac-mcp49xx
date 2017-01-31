use warnings;
use strict;
use feature 'say';

use Bit::Manip qw(:all);
use WiringPi::API qw(:all);
use RPi::WiringPi::Constant qw(:all);

use Inline  C => Config =>
            libs => ['-lwiringPi'],
            clean_after_build => 0,
            name => 'RPi::DAC::MCP4922';
use Inline 'C';

my $chan = 0;
my $cs = 18;
my $buf = 0;
my $gain = 1;
my $shdn = 22;
my $model = 12;

spi_setup($chan);
setup_gpio();

pin_mode($chan, OUTPUT);
my $b = _reg_init($buf, $gain);

say "----------------";

printf("%b init\n", $b);

$b = __set_dac($b, 1);
printf("%b dac 1\n", $b);

$b = _disable_soft($chan, $cs, 1, $b);
printf("%b disabled\n", $b);

$b = _enable_soft($chan, $cs, 1, $b);
printf("%b enabled\n", $b);

my $x = _set($chan, $cs, 1, 4, $b, 255);
printf("%b data (255) 8-bit\n", $x);

my $y = _set($chan, $cs, 1, 2, $b, 1023);
printf("%b data (1023) 10-bit\n", $y);

my $z = _set($chan, $cs, 0, 0, $b, 4095);
printf("%b data (4095) 12-bit\n", $z);

#int _set(int channel, int cs, int dac, int lsb, int buf, int data){
__END__
__C__

#include <stdio.h>
#include <stdint.h>
#include <wiringPi.h>
#include <wiringPiSPI.h>

#define MULT 2

#define DAC_BIT  15
#define BUF_BIT  14
#define GAIN_BIT 13
#define SHDN_BIT 12

int _reg_init (int buf, int gain);
int _set (int channel, int cs, int dac, int lsb, int buf, int data);
int _disable_soft (int channel, int cs, int dac, int buf);
int _enable_soft (int channel, int cs, int dac, int buf);
int __set_dac (int buf, int dac);

int _reg_init (int buf, int gain){

    /* sets the initial register values */

    int bits = 0;

    if (buf){
        bits |= 1 << BUF_BIT;
    }

    if (gain){
        bits |= 1 << GAIN_BIT;
    }

    return bits;
}

int _set(int channel, int cs, int dac, int lsb, int buf, int data){
    
    /* prepares the register for sending to a DAC */

    buf = __set_dac(buf, dac);
    int mask = ((int)pow(MULT, 12) -1) >> lsb;

    buf = (buf & ~(mask)) | (data << lsb);
    unsigned char reg[2];

    reg[0] = (buf >> 8) & 0xFF;
    reg[1] = buf & 0xFF;

    digitalWrite(cs, LOW);
    wiringPiSPIDataRW(channel, reg, 2);
    digitalWrite(cs, HIGH);
    
    return buf;
}

int _disable_soft (int channel, int cs, int dac, int buf){

    /* software shutdown of a DAC */
    
    buf = __set_dac(buf, dac);
    buf |= 1 << SHDN_BIT;
    return buf;
}

int _enable_soft (int channel, int cs, int dac, int buf){

    /* software enable of a DAC */
    
    buf = __set_dac(buf, dac);
    buf &= ~(1 << SHDN_BIT);
    return buf;
}

int __set_dac (int buf, int dac){

    /* set the DAC register bit */

    if (buf)
        buf |= 1 << DAC_BIT;
    else
        buf &= ~(1 << DAC_BIT);
  
    return buf;
}
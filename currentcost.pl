#!/usr/bin/perl -w

use strict;
use Device::SerialPort qw( :PARAM :STAT 0.07);
use XML::Parser;
use MongoDB;
use MongoDB::MongoClient;
use MongoDB::OID;
use DateTime;

# Beginning of configuration


my $PORT = "/dev/CurrentCost";
my $databaseName = "sensordata";
my $collectionName = "sensordata"; 
my $dbhost = "localhost";
my $logfile = "/var/log/currentcost";
my $detatch = 0;
my $lockfile = "/.currentcost";

# End of configuration

open( LOGFILE, ">>$logfile");
#detatch from the console
my $depth = 0;

my $parser = new XML::Parser (Style => 'Tree');


sub log{ my ($message) = @_;
	my @time = localtime(time);
	my $year = 1900 + $time[5];
	print LOGFILE sprintf("[%04u-%02u-%02u %02u:%02u:%02u] %s\n",$year,$time[4],$time[3],$time[2],$time[1],$time[0], $message);
}

sub printAtDepth{ my ($depth, $string) = @_;
	for(my $i = 0; $i < $depth; $i ++)
	{
		print "\t";
	}
	print $string;
}

my $dbClient = MongoDB::MongoClient->new( host => $dbhost );
my $db = $dbClient -> get_database( $databaseName );
my $collection = $db -> get_collection( $collectionName );

my $watts = 0;
my $channel = 0;
my $sensor = 0;
my $value = "";


sub addSensorValue{ my ($type, $sensor, $value) = @_;
	$collection -> insert( { "type" => $type,
							 "sensor" => $sensor,
							 "value" => $value,
							 "time" => DateTime->now } );
}

sub addConsumption{ my ($sensor, $channel, $watts) = @_;
	&addSensorValue("electricity",10+$channel,$watts);
}

sub addTemperature{ my ($sensor, $degreesc) = @_;
	&addSensorValue("temperature",$sensor,$degreesc);
}

sub processTree{ my ($tag, $content) = @_;
	
	if("$tag" eq "sensor")
	{
		$sensor = $content->[2];
	}
	elsif($tag =~ m/ch([0-9])/)
	{
		$channel = $1;
		&processTree(@$content[1,2]);
		&addConsumption($sensor,$channel,$watts);
	}
	elsif("$tag" eq "watts")
	{
		$watts = $content->[2];
	}
	elsif( "$tag" eq "hist")
	{
		return;
	}
	elsif( "$tag" eq "tmpr")
	{
		&addTemperature(0,$content->[2]);
	}
	elsif( ref $content ){
		my $attributes = $content->[0];
		# content is an xml element.
		for(my $i = 1; $i < $#$content; $i+=2)
		{
			&processTree(@$content[$i,$i+1]);
		}
	}
	else
	{
		$value = $content;
	}
}


if( -e $lockfile )
{
	print "Lock file $lockfile exists.  Delete this before starting.\n";
	exit(0);
}

if($detatch)
{
	if(fork())
	{
		exit(0);
	}
	&log("Detatched from console.");
}
&log("Sleeping for 10 seconds.");
sleep(10);
&log("Attempting to open socket.");
my $dev = new Device::SerialPort($PORT) or &log("Unable to open socket. $!");
$dev->baudrate(57600);
# $dev->write_settings;

open(SERIAL, "+>$PORT");

while(my $line = <SERIAL>)
{
	chomp $line;
	my $tree = $parser->parse($line);
	&processTree(@$tree);
}

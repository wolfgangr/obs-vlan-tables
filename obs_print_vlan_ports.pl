#!/usr/bin/perl

# work in progress, don't use, expect the worst
# (C) Wolfgang Rosner Dez 2024 - wolfgangr@github.com
# covered by UNLICENSE

use warnings;
use strict;
use Data::Dumper;   
use Data::Table;
use DBI;
use Text::Table; 
use Getopt::Long;

# default settings, may be overriden by cmd line options
my $debug = 3;
my $label_device = 21;  # device_ID where the vlan-labels are authoritative
my $min_vlan = 2;       # lowest vlan number to display
my $credential_file = './credentials.in';

my %options =();
GetOptions (  \%options,
	   "vlan|v=s",	# <vlan   grep pattern>      - default ''
	 "device|i=s",	# <device grep pattern>      - default ''
	  "minvl|m=i",	# <min vlan ID>              - default $min_vlan
  	 "labeld|l=i",  # <device ID> 	- default $label_device
  	   "user|u=s",  # <./file>  - default '$credential_file'

  	    "csv|c", 
  	   "html|t",
  	 "pretty|y",
  	   "dump|p",


          "debug|d=i",            # debug level
           "help|h|?",
                ) or usage ();

if ($options{help}) {
        usage ();
}

$debug = $options{debug} // $debug;
debug(5, '\%config: ' . Dumper(\%options));
$credential_file 	= $options{user} 	// $credential_file;
$label_device 		= $options{labeld}	// $label_device;
$min_vlan 		= $options{minvl} 	// $min_vlan;
my $grep_device		= $options{device}	// '';
my $grep_vlan		= $options{vlan}	// '';

my $out_mask 
	=  ($options{csv}    ? 8 : 0 )
        |  ($options{html}   ? 4 : 0 )
        |  ($options{pretty} ? 2 : 0 )
        |  ($options{dump}   ? 1 : 0 ) ;

my $outmode;
if    ( $out_mask == 8 ) { $outmode = 'csv'    ; }
elsif ( $out_mask == 4 ) { $outmode = 'html'   ; }
elsif ( $out_mask == 2 ) { $outmode = 'pretty' ; }
elsif ( $out_mask == 1 ) { $outmode = 'dump'   ; }
elsif ( $out_mask == 0 ) { $outmode = 'pretty' ; }
else {  die "select only one of output formats"; }

debug(5, "\$outmode: $outmode \n");

exit if $debug >= 6;

our ($hostname, $database, $user, $password);
require  $credential_file; #  './credentials.in';

# my $dsn = "DBI:MariaDB:database=$database;host=$hostname";
my $dsn = "DBI:mysql:database=$database;host=$hostname";
my $dbh = DBI->connect($dsn, $user, $password);
debug(2,  "established database connection to $database @ $hostname\n");
#--------------------------------------------------------------------------

# --- devices ---
my $dv_sql = <<"EODV";
SELECT device_id , hostname , sysName , ip 
FROM devices;
EODV

my @devices = retrieve_sql($dv_sql);
debug (3,  scalar @devices . " devices: rows found.\n");
# print '\@devices = ', Dumper(\@devices);
my %devices_byID = map { ( $_->{'device_id'} , $_  ) } @devices;
debug(5,  '\%devices_byID = ' .  Dumper(\%devices_byID) );

# --- port_vlans ---
my $pv_sql = <<"EOPV";
SELECT port_vlan_id, vlan, device_id, port_id 
FROM ports_vlans 
WHERE vlan >= $min_vlan
ORDER BY device_id, vlan, port_id
EOPV

my @port_vlans = retrieve_sql($pv_sql);
debug (3,  scalar @port_vlans . " port_vlans: rows found.\n");
# print '\@port_vlans = ', Dumper(\@port_vlans);
# my %port_vlans_byID = map { ( $_->{'port_vlan_id'} , $_  ) } @port_vlans;
# print '\%vlans_byID = ', Dumper(\%port_vlans_byID);

# --- ports ---
my $pt_sql = <<"EOPT";
SELECT port_id,  port_label , ifIndex, ifType, ifPhysAddress, ifVlan, ifTrunk   
FROM ports 
EOPT

my @ports= retrieve_sql($pt_sql);
debug (3, scalar @ports . " ports: rows found.\n");
# print '\@ports = ', Dumper(\@ports);
my %ports_byID = map { ( $_->{port_id} , $_  ) } @ports;
# print '\%ports_byID = ', Dumper(\%ports_byID);

# --- vlans ---
my $vl_sql = <<"EOVL";
SELECT vlan_ID, vlan_vlan, vlan_name, device_ID from vlans 
WHERE vlan_vlan >= $min_vlan
ORDER by vlan_vlan
EOVL

my @vlans = retrieve_sql($vl_sql);
debug (3, scalar @vlans . " vlans: rows found.\n");
# print '\@vlans = ' , Dumper(\@vlans);
my %vlans_byID = map { ( $_->{vlan_ID} , $_  ) } @vlans;
# print '\%vlans_byID = ', Dumper(\%vlans_byID);

if ($outmode eq 'dump') { 
  # print Data::Dumper->Dump([$foo, $bar], [qw(foo *ary)]);
  # print Data::Dumper->Dump ([\%vlans_byID] );
  print Data::Dumper->Dump (
	[   \@vlans, \@ports, \@port_vlans, \@devices  ], 
	[qw (@vlans  @ports    @port_vlans   @devices)]);
  exit;
}

# ================== reorganize data ==========================
# column headers aka vlans
my $re = qr/$grep_vlan/;
my %vlan_names = 
	map { ( $_->{vlan_vlan} , $_ ) } 
	grep { $_->{vlan_vlan} =~ /$re/ or $_->{vlan_name} =~ /$re/ }
	grep { $_->{device_ID} == $label_device } 
	@vlans;
# print '\%vlan_names = ', Dumper(\%vlan_names);

# print "-------- column headers ------------\n";
my @columns;
for my $col (sort { $a <=> $b } keys %vlan_names) {
  push @columns, $vlan_names{$col} ;
}
# print '\@columns = ', Dumper(\@columns);
#for (@columns) {
#   printf "vlan tag: %4d - name: %s\n", $_->{vlan_vlan}, $_->{vlan_name};
#}

# row headers aka devices
# print '\@devices = ', Dumper(\@devices);
my $re2 = qr/$grep_device/;
my %devices_by_name = 
	map { ( $_->{'sysName'} , $_  ) } 
	grep { $_ =~ /$re2/ or $_->{sysName} =~ /$re2/ }
	@devices;
# print '\%devices_name = ', Dumper(\%devices_by_name);
# print "-------- row headers ------------\n";
my @rows;
for my $row (sort keys %devices_by_name) {
  push @rows, $devices_by_name{$row} ;
}
# print '\@rows = ', Dumper(\@rows);
# for (@rows) {
#  printf "device id = %3d; IP = %14s; name = %s \n", 
#        $_->{device_id}, $_->{ip}, $_->{sysName};
# }

# rehash port data
# my $portmap->{device}->{vlan}= \@portlist
# print '\@port_vlans = ', Dumper(\@port_vlans);
my %portmap = ();
for my $r (@port_vlans) {
  push @{$portmap{$r->{device_id}}->{$r->{vlan}}}, $r;
}
# print '\%portmap = ', Dumper(\%portmap);


# build table
my @header1 = ('device' , 'name', 'IP' ,  map {  $_->{vlan_vlan} } @columns);
my @header2 = ('', '', '' ,  map {  $_->{vlan_name} } @columns);

my $sep =  "\n ";
if ($outmode eq 'csv') {
  $sep = '|';
} elsif ($outmode eq 'html') {
  $sep = '<br>';
}

my @body; 
for my $r (@rows) {
  my @row;
  push @row, $r->{device_id}, $r->{sysName}, $r->{ip};
  for my $c (@columns) {
    my $ports = $portmap{$r->{device_id}}->{$c->{vlan_vlan}} ;
    my @entries =();
    for my $p (@$ports) {
      my $entry =  $ports_byID{ $p->{port_id} }->{'port_label'}  ;
      $entry .= '-U' if $ports_byID{ $p->{port_id} }->{'ifVlan'} == $c->{vlan_vlan} ; 
      push @entries, $entry;
    }
    push @row, join $sep, @entries  ;
  }
  push  @body, \@row ;
}

if ($outmode eq 'html' or $outmode eq 'csv') {       # ----  Data::Table output
  unshift @body, \@header2;
  my $table = Data::Table->new(\@body, \@header1  , 0);
  if ($outmode eq 'csv') {
    print $table->csv;
  } elsif ($outmode eq 'html') {
    print $table->html;
  } else { die "not implemented" ; }

} elsif ($outmode eq 'pretty') {       # ----- Text::Table output
   
  my @tt_header = (\'|') ;
  for my $i ( 0 .. $#header1) {
    push @tt_header , $header1[$i]  . "\n" . $header2[$i];
    push @tt_header , \'|';
  }
  debug (5, @tt_header . "\n") ;
  my $tb = Text::Table->new( @tt_header );
  $tb->load( @body);
  print $tb;
# } elsif ($outmode eq 'dump') {      # ------ Data::Dumper output
#   die "TBD: Data::Dumper output";
} else { die "\$outmode $outmode  not implemented" ; }


exit;
#============ subs =========================================

# my \@result = retrieve_sql ($sql) 
sub retrieve_sql {
  my $sql = shift;
  my $sth = $dbh->prepare($sql) or die $dbh->errstr();
  $sth->execute() or die 'execution failed: ' . $dbh->errstr();

  my @ret;
  while (my  $row = $sth->fetchrow_hashref()) {
    push @ret, $row;
  }
  return @ret;

}


sub debug {
  my ($l, $msg) = @_;
  return if $l > $debug;
  print STDERR 'DEBUG: ', $msg ;
}

# http://stackoverflow.com/questions/7651/ddg#7657
sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

sub usage {
# print "$0:\n";
        print  <<"EOU";
$0
retrieve port assignemnt to vlans per device 
from observium database
  -v|vlan    <vlan   grep pattern>      - default ''
  -i|device  <device grep pattern>      - default ''
  -m|minvl   <min vlan ID>		- default $min_vlan
  -l|labeld  <device ID>                - default $label_device
	device from which vlan label names are used
  -u|--user <./file>     	        - default '$credential_file'
	database credential file (perl syntax)

table output format
  -c|csv
  -t|html
  -y|pretty
  -p|dump

Supplementary commands:
  -d|--debug <level>   - default: $debug
  -h|--help
        show this message

EOU
        exit (0);
} # - end of sub usage -




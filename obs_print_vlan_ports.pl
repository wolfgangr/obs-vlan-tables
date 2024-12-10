#!/usr/bin/perl

# work in progress, don't use, expect the worst
# (C) Wolfgang Rosner Dez 2024 - wolfgangr@github.com
# covered by UNLICENSE

use warnings;
use strict;
use Data::Dumper;   
use DBI;
use Text::Table; 

my $debug = 5;
my $label_device = 21;  # device_ID where the vlan-labels are authoritative


our ($hostname, $database, $user, $password);
require './credentials.in';

# my $dsn = "DBI:MariaDB:database=$database;host=$hostname";
my $dsn = "DBI:mysql:database=$database;host=$hostname";
my $dbh = DBI->connect($dsn, $user, $password);
print "established database connection to $database @ $hostname\n";
#--------------------------------------------------------------------------

# --- devices ---
my $dv_sql = <<"EODV";
SELECT device_id , hostname , sysName , ip 
FROM devices;
EODV

my @devices = retrieve_sql($dv_sql);
print scalar @devices . " devices: rows found.\n";
# print '\@devices = ', Dumper(\@devices);
my %devices_byID = map { ( $_->{'device_id'} , $_  ) } @devices;
# print '\%devices_byID = ', Dumper(\%devices_byID);

# --- port_vlans ---
my $pv_sql = <<"EOPV";
SELECT port_vlan_id, vlan, device_id, port_id 
FROM ports_vlans 
WHERE vlan > 1
ORDER BY device_id, vlan, port_id
EOPV

my @port_vlans = retrieve_sql($pv_sql);
print scalar @port_vlans . " port_vlans: rows found.\n";
# print '\@port_vlans = ', Dumper(\@port_vlans);
# my %port_vlans_byID = map { ( $_->{'port_vlan_id'} , $_  ) } @port_vlans;
# print '\%vlans_byID = ', Dumper(\%port_vlans_byID);

# --- ports ---
my $pt_sql = <<"EOPT";
SELECT port_id,  port_label , ifIndex, ifType, ifPhysAddress, ifVlan, ifTrunk   
FROM ports 
EOPT

my @ports= retrieve_sql($pt_sql);
print scalar @ports . " ports: rows found.\n";
# print '\@ports = ', Dumper(\@ports);
my %ports_byID = map { ( $_->{port_id} , $_  ) } @ports;
# print '\%ports_byID = ', Dumper(\%ports_byID);

# --- vlans ---
my $vl_sql = <<"EOVL";
SELECT vlan_ID, vlan_vlan, vlan_name, device_ID from vlans 
ORDER by vlan_vlan
EOVL

my @vlans = retrieve_sql($vl_sql);
print scalar @vlans . " vlans: rows found.\n";
# print '\@vlans = ' , Dumper(\@vlans);
my %vlans_byID = map { ( $_->{vlan_ID} , $_  ) } @vlans;
# print '\%vlans_byID = ', Dumper(\%vlans_byID);

# ================== reorganize data ==========================
# column headers aka vlans
my %vlan_names = map { ( $_->{vlan_vlan} , $_  ) } 
	grep { $_->{device_ID} == $label_device } @vlans;
# print '\%vlan_names = ', Dumper(\%vlan_names);

print "-------- column headers ------------\n";
my @columns;
for my $col (sort { $a <=> $b } keys %vlan_names) {
  push @columns, $vlan_names{$col} ;
}
# print '\@columns = ', Dumper(\@columns);
for (@columns) {
   printf "vlan tag: %4d - name: %s\n", $_->{vlan_vlan}, $_->{vlan_name};
}

# row headers aka devices
# print '\@devices = ', Dumper(\@devices);
my %devices_by_name = map { ( $_->{'sysName'} , $_  ) } @devices;
# print '\%devices_name = ', Dumper(\%devices_by_name);
print "-------- row headers ------------\n";
my @rows;
for my $row (sort keys %devices_by_name) {
  push @rows, $devices_by_name{$row} ;
}
# print '\@rows = ', Dumper(\@rows);
for (@rows) {
  printf "device id = %3d; IP = %14s; name = %s \n", 
        $_->{device_id}, $_->{ip}, $_->{sysName};
}

die "####==========================~~~~~~~~~~~~~~~~~~~~-----------------------";
# rehash port data
# my $portmap->{device}->{vlan}= \@portlist
# print '\@port_vlans = ', Dumper(\@port_vlans);
my %portmap = ();
for my $r (@port_vlans) {
  push @{$portmap{$r->{device_id}}->{$r->{vlan}}}, $r;
}
# print '\%portmap = ', Dumper(\%portmap);


# build table
# my $tb = Text::Table->new('', '', 




# print table

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
  print STDERR 'DEBUG: ', $msg if $l <= $debug;
}

# http://stackoverflow.com/questions/7651/ddg#7657
sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}


#!/usr/bin/perl

# work in progress, don't use, expect the worst
# (C) Wolfgang Rosner Dez 2024 - wolfgangr@github.com
# covered by UNLICENSE

use warnings;
use strict;
use Data::Dumper;   
use DBI;

my $debug = 5;

our ($hostname, $database, $user, $password);
require './credentials.in';

# my $dsn = "DBI:MariaDB:database=$database;host=$hostname";
my $dsn = "DBI:mysql:database=$database;host=$hostname";
my $dbh = DBI->connect($dsn, $user, $password);

print "established database connection to $database @ $hostname\n";


my $sql = 'SELECT device_id , hostname , sysName , ip FROM devices;';
# my $sth = $dbh->prepare($sql) or die $dbh->errstr();
# $sth->execute() or die 'execution failed: ' . $dbh->errstr();

# print $sth->rows() . " rows found.\n";

# my @devices;
# while (my  $row = $sth->fetchrow_hashref()) {
#   push @devices, $row;
# }

my @devices = retrieve_sql($sql);

print scalar @devices . " rows found.\n";

print Dumper(\@devices);






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


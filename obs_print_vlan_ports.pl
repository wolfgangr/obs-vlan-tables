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

my $sql = 'SELECT device_id , hostname , sysName , ip FROM devices;';
my $sth = $dbh->prepare($sql) or die $dbh->errstr();
$sth->execute() or die 'execution failed: ' . $dbh->errstr();

print $sth->rows() . " rows found.\n";

# my $sth = $dbh->prepare(
#    'SELECT id, first_name, last_name FROM authors WHERE last_name = ?'
# ) or die 'prepare statement failed: ' . $dbh->errstr();
# $sth->execute('Eggers') or die 'execution failed: ' . $dbh->errstr();
# print $sth->rows() . " rows found.\n";
# while (my $ref = $sth->fetchrow_hashref()) {
#     print "Found a row: id = $ref->{'id'}, fn = $ref->{'first_name'}\n";
# }





exit;
#============ subs =========================================

sub debug {
  my ($l, $msg) = @_;
  print STDERR 'DEBUG: ', $msg if $l <= $debug;
}

# http://stackoverflow.com/questions/7651/ddg#7657
sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}


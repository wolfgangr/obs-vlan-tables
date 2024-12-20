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
my $debug = 0;
my $label_device = 21;  # device_ID where the vlan-labels are authoritative
my $min_vlan = 2;       # lowest vlan number to display
my $credential_file = './credentials.in';

my %options =();
GetOptions (  \%options,
	   "vlan|v=s",	# <vlan   grep pattern>      - default ''
	 "device|i=s",	# <device grep pattern>      - default ''
        "deleted|x",	# 	don't exclude deleted fdb entries

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
debug(5,  '\%vlans_byID = ' .  Dumper(\%vlans_byID)) ;
my %vlans_by_vlan = map { ( $_->{vlan_vlan} , $_  ) } @vlans;
debug(5,  '\%vlans_by_vlan = ' .  Dumper(\%vlans_by_vlan)) ;
# die " die at =============== vlan by ID \n";

# --- vlans_fdb ---
my $vlfdb_sql = <<"EOVLFDB";
SELECT * from vlans_fdb 
EOVLFDB

my @vlan_fdb = retrieve_sql($vlfdb_sql);
debug (3, scalar @vlan_fdb . " vlan_fdb: rows found.\n");
debug(5,  '\@vlan_fdb = ' . Dumper(\@vlan_fdb));


# --- ip_mac ---
my $im_sql = <<"EOIPMAC";
SELECT	mac_id,	device_id, mac_address,	ip_address, ip_version
FROM ip_mac
EOIPMAC

my @ip_mac = retrieve_sql($im_sql);
debug (3, scalar @ip_mac . " ip_mac: rows found.\n");
debug(5,  '\@ip_mac = ' , Dumper(\@ip_mac));
my %IP_by_mac = map { ( $_->{mac_address} , $_  ) } @ip_mac;
debug(5,  '\%IP_by_mac = ' . Dumper(\%IP_by_mac)) ;

#============== end of loading

if ($outmode eq 'dump') { 
# if (0) {
  print Data::Dumper->Dump (
	[   \@vlans,  \@devices, \@vlan_fdb, \@ip_mac  ], 
	[qw (@vlans    @devices   @vlan_fdb   @ip_mac    )]);
  exit;
}

# ================== reindex data ==========================

# devices are column headers for fdb listing
my $red = qr/$grep_device/;
my $rev = qr/$grep_vlan/;


my %devices_by_name = 
	map { ( $_->{'sysName'} , $_  ) } 
	grep { $_ =~ /$red/ or $_->{sysName} =~ /$red/ }
	@devices;
# print '\%devices_name = ', Dumper(\%devices_by_name);
# print "-------- row headers ------------\n";
my @columns;
for my $c (sort keys %devices_by_name) {
  push @columns, $devices_by_name{$c} ;
}

debug (3, scalar @columns . " device columns left after filtering\n");
debug (4, 'filtered devices: ' . (join ', ' , map { $_->{sysName} } @columns) . "\n");
debug(5, '\@columns = '. Dumper(\@columns));


my %row_macs = ();
for my $f (@vlan_fdb) {
  next if ((not $options{deleted}) and $f->{deleted});

  my $myvl   = $vlans_by_vlan{$f->{vlan_id}};
  my $mysdev = $devices_byID{$f->{device_id}};

  if ($options{vlan}) {
    next unless defined $myvl;
    next unless defined $myvl->{vlan_vlan};
    next unless defined $myvl->{vlan_name};

  }
  if ( $rev  and defined $myvl) { # and defined $myvl  ) {
    next unless  ( $myvl->{vlan_vlan} =~ /$rev/ or $myvl->{vlan_name} =~ /$rev/ ) ;
  }

  # my $mysdev = $devices_byID{$f->{device_id}};
  if ( $red ) {   # and defined $mysdev ) {
    next  unless ( $f->{device_id}  =~ /$red/ or  $mysdev->{sysName} =~ /$red/ ) ;
  }

  $row_macs{$f->{mac_address}}->{fdb}->{$f->{device_id}}->{$f->{fdb_id}} = $f;
} 
debug(5, '\%row_macs = '. Dumper(\%row_macs));
debug (3, (scalar keys %row_macs) . " mac addresses in output row list\n");

my @rows = sort keys %row_macs;
# debug (0, (join ';',  @rows) . "\n");

my @header1 = ('mac' , 'device', 'IP' ,  map {  $_->{sysName} } @columns);
my @header2 = ('', '', '' ,  map {  $_->{ip} } @columns);


# cell format spec for multiple entries
# devNl => device name length
# nl    => new line separator
# is    => in line separator
# ipl   => items per line
# cpl   => characters per lin

my $cfspec;
if ($outmode eq 'pretty') {
  # my $sep = ', '; #   "\n ";
  # $cfspec = { is => ',' , nl => "\n ", ipl => 3, devNl => 15 };
  $cfspec = { is => ',' , nl => "\n~", cpl => 15, devNl => 15 };
} elsif ($outmode eq 'csv') {
  # $sep = '|';
  $cfspec = { is => ':' }
} elsif ($outmode eq 'html') {
  # $sep = '<br>';
  $cfspec = { is => ',' , nl => "<br>", ipl => 3, devNl => 30 };
}

my @body; 
for my $r (@rows) {
  my @row;
  push @row, $r;

  my $dtid ;
  if ( my $d_t = $IP_by_mac{$r} ) {
    $dtid = $devices_byID{ $d_t->{device_id}   };
  }
  if ($dtid ) {
    if (my $ll = $cfspec->{devNl}) {  # limit device name length
      push @row, substr( $dtid->{sysName} ,0,$ll) ;
    } else {
      push @row,  $dtid->{sysName}  ;
    }

    push @row, $dtid->{ip};
  } else {
    push @row, qw(? -);
  }

  for my $c (@columns) {
    #   $row_macs{$f->{mac_address}}->{fdb}->{$f->{device_id}}->{$f->{fdb_id}} = $f;
    my $rc_fdb = $row_macs{$r}->{fdb}->{$c->{device_id}};
    # print Dumper($c, $r,  $rc_fdb);
    my @entries =  
	sort  { $a <=> $b }
	grep { $_ >= $min_vlan } 
	map { $rc_fdb->{$_}->{vlan_id}  } 
	keys %$rc_fdb;

    my $cell = shift @entries;  # simple case - fine for most cells

    if (scalar @entries) {   	# i.e. more than one entry
      my $icnt = 1;
      my $ccnt = length($cell);
      while (my $ne = shift @entries) {
        if ( (defined $cfspec->{ipl} and $icnt >=  $cfspec->{ipl} ) or
             (defined $cfspec->{cpl} and $ccnt >=  $cfspec->{cpl} ) )   {
           # new line
          $cell .= $cfspec->{nl} . $ne;
          $icnt = 1;
          $ccnt = length($ne);
        } else {    # continue on line
          $cell .= $cfspec->{is} . $ne; 
          $icnt++;
          $ccnt += length($cfspec->{is}) + length($ne);
        }

      }
    }
    push @row, $cell;
    # push @row, join $sep, @entries  ;
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
retrieve 802.1Q vlan filter database entries  
	from observium database

  -v|vlan    <vlan   grep pattern>      - default ''
  -i|device  <device grep pattern>      - default ''
  -x|deleted 				- default off
	don't exclude deleted fdb entries

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




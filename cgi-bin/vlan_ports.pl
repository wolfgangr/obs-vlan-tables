#!/usr/bin/perl

use warnings;
use strict;

use CGI;
use Data::Dumper;
use Regexp::Wildcards;

my $debug=0;

my $q = CGI->new;  
my $hostname = $q->server_name();
my $obsport=8081;

my %params = $q->Vars;
if ($debug and %params) {
  print "Content-type: text/plain\n\n";
  print Dumper(\%params) if %params;
  exit;
}

my $fmt =  't';
if ($params{'fmt'} and $params{'fmt'} =~ /^[ctyp]$/ ) { 
  # (^[ctyp]$)
  $fmt =  $params{'fmt'};
}
my $opts = "-$fmt";

# we allow wildcards only since regexp are hard to sanitize
my $rw = Regexp::Wildcards->new(type => 'unix');
my $vgrep = '';
# ^[\w_\-\*\.,{}]+$
if ($params{'vgrep'} and $params{'vgrep'} =~ /^[\w_\-\*\.,{}?]+$/ ) {
  $vgrep = $params{'vgrep'}; 
  my $rx =  $rw->convert($vgrep)  ;
  $opts .= " -v '^$rx\$' " if $rx ;
}

my $dgrep = '';
if ( $params{'dgrep'} and $params{'dgrep'} =~ /^[\w_\-\*\.,{}?]+$/  ) {
  $dgrep = $params{'dgrep'}; 
  my $rx =  $rw->convert(  $dgrep ) ;
  $opts .= " -i '^$rx\$' " if $rx ;
}

# minvlid
my $minvlid = '';
# (^\d+$) sanitize: digits only
if ($params{'minvlid'} and $params{'minvlid'} =~ /^\d+$/ ) {
  $minvlid = $params{'minvlid'};
  $opts .= " -m $minvlid ";
}

# labeldev
my $labeldev = '';
if ($params{'labeldev'} and $params{'labeldev'} =~ /^\d+$/ ) {
  $labeldev = $params{'labeldev'};
  $opts .= " -l $labeldev ";
}



my $cmd = sprintf (
    "cd /home/wrosner/snmp/topology/observium_db/ && ./obs_print_vlan_ports.pl %s 2>/dev/null",
    $opts);

# print html1();
# my $output =`cd /home/wrosner/snmp/topology/observium_db/ && ./obs_print_vlan_ports.pl -t 2>/dev/null`;
my $output =`$cmd`;

if ($fmt eq 't') {
  print html1();
  print $output;
  print "</BODY>\n</HTML>\n";
  exit;
} else {
  print "Content-type: text/plain\n\n";
  print $output;
  exit;
}



print "kilroy, you again??";
exit;


#==========================================

sub html1 {
return <<"EOHTML";
Content-type: text/html

<HTML>
<HEAD>
<TITLE>vlan ports per device</TITLE>
</HEAD>
<BODY>
<h3>vlan ports per device</h3>
<p>extracted from current state of  
<a href="http://$hostname:$obsport/vlan/" target="_blank">observium</a> 
sql data</p>
</p>
<form  method="get">
  <table><tr><td>
      <label>vlan wildcard</label><br>
        <input type="text" name="vgrep" value="$vgrep">
    </td><td>
      <label>device wildcard</label><br>
        <input type="text" name="dgrep" value="$dgrep"><br>
    </td><td>
      <label>min vlan ID</label><br>
        <input type="text" name="minvlid" value="$minvlid"><br>
    </td><td>
      <label>vlan labels from device</label><br>
        <input type="text" name="labeldev" value="$labeldev"><br>
  </td></tr>
  <tr><td align="right">output format:</td>
  <td colspan=3>
    <fieldset>
      <input type="radio" id="t" name="fmt" value="t" checked>
        <label for="t">HTML</label> 
      <input type="radio" id="c" name="fmt" value="c" >
        <label for="c">CSV</label> 
      <input type="radio" id="p" name="fmt" value="p" >
        <label for="t">PERL dump</label> 
      <input type="radio" id="y" name="fmt" value="y" >
        <label for="y">ASCII art</label> 
    </fieldset>
  </td>
  </tr><tr>
  <td colspan=4 align="right">
    <button type="submit">Submit</button>
  </td></tr></table>
</form>
EOHTML
}


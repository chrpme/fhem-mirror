
package main;

use strict;
use warnings;
use Sys::Statistics::Linux;

sub
SYSSTAT_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}    = "SYSSTAT_Define";
  $hash->{UndefFn}  = "SYSSTAT_Undefine";
  $hash->{AttrFn}   = "SYSSTAT_Attr";
  $hash->{AttrList} = "filesystems showpercent useregex loglevel:0,1,2,3,4,5,6 ".
                       $readingFnAttributes;
}

#####################################

sub
SYSSTAT_Define($$)
{
  my ($hash, $def) = @_;

  my @a = split("[ \t][ \t]*", $def);

  return "Usage: define <name> SYSSTAT [interval]"  if(@a < 2);

  my $interval = 60;
  if(int(@a)>=3) { $interval = $a[2]; }
  if( $interval < 60 ) { $interval = 60; }

  $hash->{STATE} = "Initialized";
  $hash->{INTERVAL} = $interval;

  $hash->{xls} = Sys::Statistics::Linux->new( loadavg => 1 );

  InternalTimer(gettimeofday()+$hash->{INTERVAL}, "SYSSTAT_GetUpdate", $hash, 0);

  return undef;
}

sub
SYSSTAT_Undefine($$)
{
  my ($hash, $arg) = @_;

  RemoveInternalTimer($hash);
  return undef;
}

sub
SYSSTAT_Attr($$$)
{
  my ($cmd, $name, $attrName, $attrVal) = @_;
  my $hash = $defs{$name};

  $attrVal= "" unless defined($attrVal);
  $attrVal= "" if($cmd eq "useregex");
  $attrVal= "" if($cmd eq "showpercent");

  if( $attrName eq "filesystems") {
    my @filesystems = split(",",$attrVal);
    @{$hash->{filesystems}} = @filesystems;

    if( $#filesystems >= 0 ) {
      $hash->{xls}->set( loadavg => 1,
                         diskusage => 1 );
    } else {
      $hash->{xls}->set( loadavg => 1,
                         diskusage => 0 );
    }
  }

  return;
}

sub
SYSSTAT_GetUpdate($)
{
  my ($hash) = @_;

  if(!$hash->{LOCAL}) {
    InternalTimer(gettimeofday()+$hash->{INTERVAL}, "SYSSTAT_GetUpdate", $hash, 1);
  }

  my $stat = $hash->{xls}->get;

  my $load = $stat->{loadavg};

  $hash->{STATE} = $load->{avg_1} . " " . $load->{avg_5} . " " . $load->{avg_15};

  readingsSingleUpdate($hash,"load",$load->{avg_1},defined($hash->{LOCAL} ? 0 : 1));

  if( defined(my $usage = $stat->{diskusage}) ){

    my $type = 'free';
    if( AttrVal($hash->{NAME}, "showpercent", "") ne "" ) {
      $type = 'usageper';
    }

    if( AttrVal($hash->{NAME}, "useregex", "") eq "" ) {
      for my $filesystem (@{$hash->{filesystems}}) {
        my $fs = $usage->{$filesystem};
        readingsSingleUpdate($hash,$fs->{mountpoint},$fs->{$type},defined($hash->{LOCAL} ? 0 : 1));
      }
    } else {
      for my $filesystem (@{$hash->{filesystems}}) {
        foreach my $key (keys %$usage) {
          if( $key =~ /$filesystem/ ) {
            my $fs = $usage->{$key};
            readingsSingleUpdate($hash,$fs->{mountpoint},$fs->{$type},defined($hash->{LOCAL} ? 0 : 1));
          }
        }
      }
    }
  }
}

1;

=pod
=begin html

<a name="SYSSTAT"></a>
<h3>SYSSTAT</h3>
<ul>
  Provides system statistics for the host FHEM runs on.<br><br>

  Notes:
  <ul>
    <li>currently only Linux is supported.</li>
    <li>This module needs <code>Sys::Statistics::Linux</code> on Linux.<br>
        It can be installed with '<code>cpan install Sys::Statistics::Linux</code>'<br>
        or on debian with '<code>apt-get install libsys-statistics-linux-perl</code>'</li>
    <li>To plot the load values the following code can be used:
  <PRE>
  define sysstatlog FileLog /usr/local/FHEM/var/log/sysstat-%Y-%m.log sysstat
  attr sysstatlog nrarchive 1
  define wl_sysstat weblink fileplot sysstatlog:sysstat:CURRENT
  attr wl_sysstat label "Load Min: $data{min1}, Max: $data{max1}, Aktuell: $data{currval1}"
  attr wl_sysstat room System
  </PRE></li>
  </ul>

  <a name="SYSSTAT_Define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; SYSSTAT [&lt;interval&gt;]</code><br>
    <br>

    Defines a SYSSTAT device.<br><br>

    The statistics are updated &lt;interval&gt; seconds. The default is 60.<br><br>

    Examples:
    <ul>
      <code>define sysstat SYSSTAT</code><br>
      <code>define sysstat SYSSTAT 30</code><br>
    </ul>
  </ul><br>

  <a name="SYSSTAT_Readings"></a>
  <b>Readings</b>
  <ul>
    <li>load<br>
    the 1 minute load average</li>
    <li>state<br>
    the 1, 5 and 15 minute load averages</li>
    <li>&lt;mountpoint&gt;<br>
    free bytes for &lt;mountpoint&gt;</li>
  </ul><br>

  <a name="SYSSTAT_Attr"></a>
  <b>Attributes</b>
    <li>filesystems<br>
      List of comma separated filesystems that should be monitored.<br>
    Examples:
    <ul>
      <code>attr sysstat filesystems /dev/md0,/dev/md2</code><br>
      <code>attr sysstat filesystems /dev/.*</code><br>
    </ul></lu>
    <li>showpercent<br>
      If set the usage is shown in percent. If not set the remaining free space in bytes is shown.</li>
    <li>useregex<br>
      If set the entries of the filesystems list are treated as regex.</li>
</ul>

=end html
=cut
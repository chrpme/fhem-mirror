#
#
#
# 57_Calendar.pm
# written by Dr. Boris Neubert 2012-06-01
# e-mail: omega at online dot de
#
##############################################
# $Id$

# Todos:
#  Support recurring events


use strict;
use warnings;
use HttpUtils;


##############################################

package main;

sub debug($) {
  my ($msg)= @_;
  Log 1, "DEBUG: " . $msg;
}


#####################################
#
# ICal
# the ical format is governed by RFC2445 http://www.ietf.org/rfc/rfc2445.txt
#
#####################################

package ICal::Entry;

sub new {
  my $class= shift;
  my ($type)= @_;
  my $self= {};
  bless $self, $class;
  $self->{type}= $type;
  $self->{entries}= [];
  #main::debug "NEW: $type";
  return($self);
}

sub addproperty {
  my ($self,$line)= @_;
  # TRIGGER;VALUE=DATE-TIME:20120531T150000Z
  #main::debug "line= $line";
  my ($property,$parameter)= split(":", $line,2); # TRIGGER;VALUE=DATE-TIME    20120531T150000Z
  #main::debug "property= $property parameter= $parameter";
  my ($key,$parts)= split(";", $property,2);
  #main::debug "key= $key parts= $parts";
  $parts= "" unless(defined($parts));
  $parameter= "" unless(defined($parameter));
  $self->{properties}{$key}= {
      PARTS => "$parts",
      VALUE => "$parameter"
  };
  #main::debug "ADDPROPERTY: ". $self ." key= $key, parts= $parts, value= $parameter";
  #main::debug "WE ARE " .  $self->{properties}{$key}{VALUE};
}

sub value {
  my ($self,$key)= @_;
  return $self->{properties}{$key}{VALUE};
}

sub parts {
  my ($self,$key)= @_;
  return split(";", $self->{properties}{$key}{PARTS});
}

sub parse {
  my ($self,@ical)= @_;
  $self->parseSub(0, @ical);
}

sub parseSub {
  my ($self,$ln,@ical)= @_;
  #main::debug "ENTER @ $ln";
  while($ln<$#ical) {
    my $line= $ical[$ln];
    chomp $line;
    $line =~ s/[\x0D]//; # chomp will not remove the CR
    #main::debug "$ln: $line";
    $ln++;
    last if($line =~ m/^END:.*$/);
    if($line =~ m/^BEGIN:(.*)$/) {
      my $entry= ICal::Entry->new($1);
      push @{$self->{entries}}, $entry;
      $ln= $entry->parseSub($ln,@ical);
    } else {
      $self->addproperty($line);
    }
  }
  #main::debug "BACK";
  return $ln;
}

sub asString() {
  my ($self,$level)= @_;
  $level= "" unless(defined($level));
  my $s= $level . $self->{type} . "\n";
  $level .= "  ";
  for my $key (keys %{$self->{properties}}) {
    $s.= $level . "$key: ". $self->value($key) . "\n";
  }
  my @entries=  @{$self->{entries}};
  for(my $i= 0; $i<=$#entries; $i++) {
    $s.= $entries[$i]->asString($level);
  }
  return $s;
}

#####################################
#
# Event
#
#####################################

package Calendar::Event;

sub new {
  my $class= shift;
  my $self= {};
  bless $self, $class;
  $self->{_state}= "";
  $self->{_mode}= "undefined";
  $self->setState("new");
  $self->setMode("undefined");
  $self->{alarmTriggered}= 0;
  $self->{startTriggered}= 0;
  $self->{endTriggered}= 0;
  return($self);
}

sub uid {
  my ($self)= @_;
  return $self->{uid};
}

sub start {
  my ($self)= @_;
  return $self->{start};
}


sub setState {
  my ($self,$state)= @_;
  #main::debug "Before setState $state: States(" . $self->uid() . ") " . $self->{_previousState} . " -> " . $self->{_state};
  $self->{_previousState}= $self->{_state};
  $self->{_state}= $state;
  #main::debug "After setState $state: States(" . $self->uid() . ") " . $self->{_previousState} . " -> " . $self->{_state};
  return $state;
}

sub setMode {
  my ($self,$mode)= @_;
  $self->{_previousMode}= $self->{_mode};
  $self->{_mode}= $mode;
  #main::debug "After setMode $mode: Modes(" . $self->uid() . ") " . $self->{_previousMode} . " -> " . $self->{_mode};
  return $mode;
}

sub touch {
  my ($self,$t)= @_;
  $self->{_lastSeen}= $t;
  return $t;
}

sub lastSeen {
  my ($self)= @_;
  return $self->{_lastSeen};
}

sub state {
  my ($self)= @_;
  return $self->{_state};
}

sub mode {
  my ($self)= @_;
  return $self->{_mode};
}

sub lastModified {
  my ($self)= @_;
  return $self->{lastModified};
}

sub isState {
  my ($self,$state)= @_;
  return $self->{_state} eq $state ? 1 : 0;
}

sub isNew {
  my ($self)= @_;
  return $self->isState("new");
}

sub isKnown {
  my ($self)= @_;
  return $self->isState("known");
}

sub isUpdated {
  my ($self)= @_;
  return $self->isState("updated");
}

sub isDeleted {
  my ($self)= @_;
  return $self->isState("deleted");
}


sub stateChanged {
  my ($self)= @_;
  #main::debug "States(" . $self->uid() . ") " . $self->{_previousState} . " -> " . $self->{_state};
  return $self->{_state} ne $self->{_previousState} ? 1 : 0;
}

sub modeChanged {
  my ($self)= @_;
  return $self->{_mode} ne $self->{_previousMode} ? 1 : 0;
}

# converts a date/time string to the number of non-leap seconds since the epoch
# 20120520T185202Z: date/time string in ISO8601 format, time zone GMT
# 20120520:         a date string has no time zone associated
sub tm {
  my ($t)= @_;
  #main::debug "convert $t";
  my ($year,$month,$day)= (substr($t,0,4), substr($t,4,2),substr($t,6,2));
  if(length($t)>8) {
      my ($hour,$minute,$second)= (substr($t,9,2), substr($t,11,2),substr($t,13,2));
      return main::fhemTimeGm($second,$minute,$hour,$day,$month-1,$year-1900);
  } else {
      #main::debug "$day $month $year";
      return main::fhemTimeLocal(0,0,0,$day,$month-1,$year-1900);
  }
}

#      DURATION RFC2445
#      dur-value  = (["+"] / "-") "P" (dur-date / dur-time / dur-week)
#
#      dur-date   = dur-day [dur-time]
#      dur-time   = "T" (dur-hour / dur-minute / dur-second)
#      dur-week   = 1*DIGIT "W"
#      dur-hour   = 1*DIGIT "H" [dur-minute]
#      dur-minute = 1*DIGIT "M" [dur-second]
#      dur-second = 1*DIGIT "S"
#      dur-day    = 1*DIGIT "D"
#
#      example: -P0DT0H30M0S
sub d {
  my ($d)= @_;

  #main::debug "Duration $d";
  
  my $sign= 1;
  my $t= 0;

  my @c= split("P", $d);
  $sign= -1 if($c[0] eq "-");
  shift @c if($c[0] =~ m/[\+\-]/);
  my ($dw,$dt)= split("T", $c[0]);
  $dt="" unless defined($dt);
  if($dw =~ m/(\d+)D$/) {
    $t+= 86400*$1; # days
  } elsif($dw =~ m/(\d+)W$/) {
    $t+= 604800*$1; # weeks
  }
  if($dt =~ m/^(\d+)H(\d+)M(\d+)S$/) {
    $t+= $1*3600+$2*60+$3;
  }
  $t*= $sign;
  #main::debug "sign: $sign  dw: $dw  dt: $dt   t= $t";
  return $t;
}

sub dt {
  my ($t0,$value,$parts)= @_;
  #main::debug "t0= $t0  parts= $parts  value= $value";
  if(defined($parts) && $parts =~ m/VALUE=DATE/) {
    return tm($value);
  } else {
    return $t0+d($value);
  }
}

sub ts {
  my ($tm)= @_;
  return "" unless($tm);
  my ($second,$minute,$hour,$day,$month,$year,$wday,$yday,$isdst)= localtime($tm);
  return sprintf("%02d.%02d.%4d %02d:%02d:%02d", $day,$month+1,$year+1900,$hour,$minute,$second);
}

sub ts0 {
  my ($tm)= @_;
  return "" unless($tm);
  my ($second,$minute,$hour,$day,$month,$year,$wday,$yday,$isdst)= localtime($tm);
  return sprintf("%02d.%02d.%2d %02d:%02d", $day,$month+1,$year-100,$hour,$minute);
}

sub fromVEvent {
  my ($self,$vevent)= @_;

  $self->{uid}= $vevent->value("UID");
  $self->{uid}=~ s/\W//g; # remove all non-alphanumeric characters, this makes life easier for perl specials
  $self->{start}= tm($vevent->value("DTSTART"));
  $self->{end}= tm($vevent->value("DTEND"));
  $self->{lastModified}= tm($vevent->value("LAST-MODIFIED"));
  $self->{summary}= $vevent->value("SUMMARY");
  $self->{location}= $vevent->value("LOCATION");
  #$self->{summary}=~ s/;/,/g;

  #
  # recurring events
  #
  # this part is under construction
  # we have to think a lot about how to deal with the migration of states for recurring events
  my $rrule= $vevent->value("RRULE");
  if($rrule) {
    my @rrparts= split(";", $rrule);
    my %r= map { split("=", $_); } @rrparts;
    #foreach my $k (keys %r) {
    #  main::debug "Rule part $k is $r{$k}";
    #}
    my $freq= $r{"FREQ"};
    #
    # weekly
    #
    if($freq eq "WEEKLY") {
      # my @weekdays= split(",",$r{"BYDAY"});# BYDAY is not always set
    }
  }
  

  # alarms
  my @valarms= grep { $_->{type} eq "VALARM" } @{$vevent->{entries}};
  my @alarmtimes= sort map { dt($self->{start}, $_->value("TRIGGER"), $_->parts("TRIGGER")) } @valarms;
  if(@alarmtimes) {
    $self->{alarm}= $alarmtimes[0];
  } else {
    $self->{alarm}= undef;
  }
}

# sub asString {
#   my ($self)= @_;
#   return sprintf("%s  %s(%s);%s;%s;%s;%s",
#     $self->state(),
#     $self->{uid},
#     ts($self->{lastModified}),
#     $self->{alarm} ? ts($self->{alarm}) : "",
#     ts($self->{start}),
#     ts($self->{end}),
#     $self->{summary}
#   );
# }

sub summary {
  my ($self)= @_;
  return $self->{summary};
}

sub location {
  my ($self)= @_;
  return $self->{location};
}


sub asText {
  my ($self)= @_;
  return sprintf("%s %s",
    ts0($self->{start}),
    $self->{summary}
  );
}

sub asFull {
  my ($self)= @_;
  return sprintf("%s %7s %8s %s %s-%s %s %s",
    $self->uid(),
    $self->state(),
    $self->mode(),
    $self->{alarm} ? ts($self->{alarm}) : "                   ",
    ts($self->{start}),
    ts($self->{end}),
    $self->{summary},
    $self->{location}
  );
}

sub alarmTime {
  my ($self)= @_;
  return ts($self->{alarm});
}

sub startTime {
  my ($self)= @_;
  return ts($self->{start});
}

sub endTime {
  my ($self)= @_;
  return ts($self->{end});
}


# returns 1 if time is before alarm time and before start time, else 0
sub isUpcoming {
  my ($self,$t) = @_;
  return 0 if($self->isDeleted());
  if($self->{alarm}) {
    return $t< $self->{alarm} ? 1 : 0;
  } else {
    return $t< $self->{start} ? 1 : 0;
  }
}

# returns 1 if time is between alarm time and start time, else 0
sub isAlarmed {
  my ($self,$t) = @_;
  return 0 if($self->isDeleted());
  return $self->{alarm} ?
    (($self->{alarm}<= $t && $t<= $self->{start}) ? 1 : 0) : 0;
}

# return 1 if time is between start time and end time, else 0
sub isStarted {
  my ($self,$t) = @_;
  return 0 if($self->isDeleted());
  return $self->{start}<= $t && $t<= $self->{end} ? 1 : 0;
}

sub isEnded {
  my ($self,$t) = @_;
  return 0 if($self->isDeleted());
  return $self->{end}< $t ? 1 : 0;
}

sub nextTime {
  my ($self,$t) = @_;
  my @times= ( $self->{start}, $self->{end} );
  unshift @times, $self->{alarm} if($self->{alarm});
  @times= sort grep { $_ > $t } @times;

#   main::debug "Calendar: " . $self->asFull();
#   main::debug "Calendar: Start " . main::FmtDateTime($self->{start});
#   main::debug "Calendar: End   " . main::FmtDateTime($self->{end});
#   main::debug "Calendar: Alarm " . main::FmtDateTime($self->{alarm}) if($self->{alarm});
#   main::debug "Calendar: times[0] " . main::FmtDateTime($times[0]);
#   main::debug "Calendar: times[1] " . main::FmtDateTime($times[1]);
#   main::debug "Calendar: times[2] " . main::FmtDateTime($times[2]);
  
  if(@times) {
    return $times[0];
  } else {
    return undef;
  }
}

#####################################
#
# Events
#
#####################################

package Calendar::Events;

sub new {
  my $class= shift;
  my $self= {};
  bless $self, $class;
  $self->{events}= {};
  return($self);
}

sub uids {
  my ($self)= @_;
  return keys %{$self->{events}};
}

sub events {
  my ($self)= @_;
  return values %{$self->{events}};
}

sub event {
  my ($self,$uid)= @_;
  return $self->{events}{$uid};
}

sub setEvent {
  my ($self,$event)= @_;
  $self->{events}{$event->uid()}= $event;
}
sub deleteEvent {
  my ($self,$uid)= @_;
  delete $self->{events}{$uid};
}

# sub ts {
#   my ($tm)= @_;
#   my ($second,$minute,$hour,$day,$month,$year,$wday,$yday,$isdst)= localtime($tm);
#   return sprintf("%02d.%02d.%4d %02d:%02d:%02d", $day,$month+1,$year+1900,$hour,$minute,$second);
# }

sub updateFromCalendar {
  my ($self,$calendar)= @_;
  my $t= time();
  my $uid;
  my $event;

  # we first remove all elements which were previously marked for deletion
  foreach $event ($self->events()) {
    if($event->isDeleted()) {
      $self->deleteEvent($event->uid());
    }
  }

  # we iterate over the VEVENTs in the calendar
  my @vevents= grep { $_->{type} eq "VEVENT" } @{$calendar->{entries}};
  foreach my $vevent (@vevents) {
    # convert event to entry
    my $event= Calendar::Event->new();
    $event->fromVEvent($vevent);

    $uid= $event->uid();
    #main::debug "Processing event $uid.";
    #foreach my $ee ($self->events()) {
    #  main::debug $ee->asFull();
    #}
    if(defined($self->event($uid))) {
      # the event already exists
      #main::debug "Event $uid already exists.";
      $event->setState($self->event($uid)->state()); # copy the state from the existing event
      $event->setMode($self->event($uid)->mode()); # copy the mode from the existing event
      #main::debug "Our lastModified: " . ts($self->event($uid)->lastModified());
      #main::debug "New lastModified: " . ts($event->lastModified());
      if($self->event($uid)->lastModified() != $event->lastModified()) {
         $event->setState("updated");
         #main::debug "We set it to updated.";
      } else {
         $event->setState("known")
      }   
    };
    # new events that have ended are omitted 
    if($event->state() ne "new" || !$event->isEnded($t)) {
      $event->touch($t);
      $self->setEvent($event);
    }
  }

  # untouched elements get marked as deleted
  foreach $event ($self->events()) {
    if($event->lastSeen() != $t) {
      $event->setState("deleted");
    }
  }
}

#####################################

package main;



#####################################
sub Calendar_Initialize($) {

  my ($hash) = @_;
  $hash->{DefFn}   = "Calendar_Define";
  $hash->{UndefFn} = "Calendar_Undef";
  $hash->{GetFn}   = "Calendar_Get";
  $hash->{SetFn}   = "Calendar_Set";
  $hash->{AttrList}= "loglevel:0,1,2,3,4,5 event-on-update-reading event-on-change-reading";

}

###################################
sub Calendar_Wakeup($) {

  my ($hash) = @_;

  my $t= time();
  Log 4, "Calendar " . $hash->{NAME} . ": Wakeup";

  Calendar_GetUpdate($hash) if($t>= $hash->{fhem}{nxtUpdtTs});

  $hash->{fhem}{lastChkTs}= $t;
  $hash->{fhem}{lastCheck}= FmtDateTime($t);
  Calendar_CheckTimes($hash);

  # find next event
  my $nt= $hash->{fhem}{nxtUpdtTs};
  foreach my $event ($hash->{fhem}{events}->events()) {
    next if $event->isDeleted();
    my $et= $event->nextTime($t);
    # we only consider times in the future to avoid multiple
    # invocations for calendar events with the event time
    $nt= $et if(defined($et) && ($et< $nt) && ($et > $t));
  }
  $hash->{fhem}{nextChkTs}= $nt;
  $hash->{fhem}{nextCheck}= FmtDateTime($nt);

  InternalTimer($nt, "Calendar_Wakeup", $hash, 0) ;

}

###################################
sub Calendar_CheckTimes($) {

  my ($hash) = @_;

  my $eventsObj= $hash->{fhem}{events};
  my $t= time();
  Log 4, "Calendar " . $hash->{NAME} . ": Checking times...";

  # we now run over all events and update the readings 
  my @allevents= $eventsObj->events();
  my @upcomingevents= grep { $_->isUpcoming($t) } @allevents;
  my @alarmedevents= grep { $_->isAlarmed($t) } @allevents;
  my @startedevents= grep { $_->isStarted($t) } @allevents;
  my @endedevents= grep { $_->isEnded($t) } @allevents;

  my $event;
  #main::debug "Updating modes...";
  foreach $event (@upcomingevents) { $event->setMode("upcoming"); }
  foreach $event (@alarmedevents) { $event->setMode("alarm"); }
  foreach $event (@startedevents) { $event->setMode("start"); }
  foreach $event (@endedevents) { $event->setMode("end"); }

  my @changedevents= grep { $_->modeChanged() } @allevents;

  
  my @upcoming= sort map { $_->uid() } @upcomingevents;
  my @alarm= sort map { $_->uid() } @alarmedevents;
  my @alarmed= sort map { $_->uid() } grep { $_->modeChanged() } @alarmedevents;
  my @start= sort map { $_->uid() } @startedevents;
  my @started= sort map { $_->uid() } grep { $_->modeChanged() } @startedevents;
  my @end= sort map { $_->uid() } @endedevents;
  my @ended= sort map { $_->uid() } grep { $_->modeChanged() } @endedevents;
  my @changed= sort map { $_->uid() } @changedevents;
  
  readingsBeginUpdate($hash); # clears all events in CHANGED, thus must be called first
  # we create one fhem event for one changed calendar event
  map { addEvent($hash, "changed: " . $_->uid() . " " . $_->mode() ); } @changedevents;
  readingsUpdate($hash, "lastCheck", $hash->{fhem}{lastCheck});
  readingsUpdate($hash, "modeUpcoming", join(";", @upcoming));
  readingsUpdate($hash, "modeAlarm", join(";", @alarm));
  readingsUpdate($hash, "modeAlarmed", join(";", @alarmed));
  readingsUpdate($hash, "modeAlarmOrStart", join(";", @alarm,@start));
  readingsUpdate($hash, "modeChanged", join(";", @changed));
  readingsUpdate($hash, "modeStart", join(";", @start));
  readingsUpdate($hash, "modeStarted", join(";", @started));
  readingsUpdate($hash, "modeEnd", join(";", @end));
  readingsUpdate($hash, "modeEnded", join(";", @ended));
  readingsEndUpdate($hash, 1); # DoTrigger, because sub is called by a timer instead of dispatch
  
}  


###################################
sub Calendar_GetUpdate($) {

  my ($hash) = @_;

  my $t= time();
  $hash->{fhem}{lstUpdtTs}= $t;
  $hash->{fhem}{lastUpdate}= FmtDateTime($t);
  
  Log 4, "Calendar " . $hash->{NAME} . ": Updating...";
  my $url= $hash->{fhem}{url};
  
  my $ics= GetFileFromURLQuiet($url);
  if(!defined($ics)) {
    Log 1, "Calendar " . $hash->{NAME} . ": Could not retrieve file at URL";
    return 0;
  }

  # we parse the calendar into a recursive ICal::Entry structure
  my $ical= ICal::Entry->new("root");
  $ical->parse(split("\n",$ics));
  #main::debug "*** Result:\n";
  #main::debug $ical->asString();

  my @entries= @{$ical->{entries}};
  if($#entries<0) {
    Log 1, "Calendar " . $hash->{NAME} . ": Not an ical file at URL";
    $hash->{STATE}= "Not an ical file at URL";
    return 0;
  };
  
  my $root= @{$ical->{entries}}[0];
  my $calname= "?";
  if($root->{type} ne "VCALENDAR") {
    Log 1, "Calendar " . $hash->{NAME} . ": Root element is not a VCALENDAR";
    $hash->{STATE}= "Root element is not a VCALENDAR";
    return 0;
  } else {
    $calname= $root->value("X-WR-CALNAME");
  }
  
    
  $hash->{STATE}= "Active";
  
  # we now create the events from it
  #main::debug "Creating events...";
  my $eventsObj= $hash->{fhem}{events};
  $eventsObj->updateFromCalendar($root);
  $hash->{fhem}{events}= $eventsObj;

  # we now update the readings
  my @allevents= $eventsObj->events();

  my @all= sort map { $_->uid() } @allevents;
  my @new= sort map { $_->uid() } grep { $_->isNew() } @allevents;
  my @updated= sort map { $_->uid() } grep { $_->isUpdated() } @allevents;
  my @deleted = sort map { $_->uid() } grep { $_->isDeleted() } @allevents;
  my @changed= sort (@new, @updated, @deleted);

  #$hash->{STATE}= $val;
  readingsBeginUpdate($hash);
  readingsUpdate($hash, "calname", $calname);
  readingsUpdate($hash, "lastUpdate", $hash->{fhem}{lastUpdate});
  readingsUpdate($hash, "all", join(";", @all));
  readingsUpdate($hash, "stateNew", join(";", @new));
  readingsUpdate($hash, "stateUpdated", join(";", @updated));
  readingsUpdate($hash, "stateDeleted", join(";", @deleted));
  readingsUpdate($hash, "stateChanged", join(";", @changed));
  readingsEndUpdate($hash, 1); # DoTrigger, because sub is called by a timer instead of dispatch

  $t+= $hash->{fhem}{interval};
  $hash->{fhem}{nxtUpdtTs}= $t;
  $hash->{fhem}{nextUpdate}= FmtDateTime($t);

  return 1;
}

###################################
sub Calendar_Set($@) {
  my ($hash, @a) = @_;

  my $cmd= $a[1];

  # usage check
  if((@a == 2) && ($a[1] eq "update")) {
     $hash->{fhem}{nxtUpdtTs}= 0; # force update
     Calendar_Wakeup($hash);
     return undef;
  } else {
    return "Unknown argument $cmd, choose one of update";
  }
}

###################################
sub Calendar_Get($@) {

  my ($hash, @a) = @_;


  my $eventsObj= $hash->{fhem}{events};
  my @events;

  my $cmd= $a[1];
  if(grep(/^$cmd$/, ("text","full","summary","location","alarm","start","end"))) {

    return "argument is missing" if($#a != 2);
    my $reading= $a[2];
    
    # $reading is alarmed, all, changed, deleted, new, started, updated
    # if $reading does not match any of these it is assumed to be a uid
    if(defined($hash->{READINGS}{$reading})) {
      @events= grep { my $uid= $_->uid(); $hash->{READINGS}{$reading}{VAL} =~ m/$uid/ } $eventsObj->events();
    } else {
      @events= grep { $_->uid() eq $reading } $eventsObj->events();
    }

    my @texts;

    
    if(@events) {
      foreach my $event (sort { $a->start() <=> $b->start() } @events) {
        push @texts, $event->asText() if $cmd eq "text";
        push @texts, $event->asFull() if $cmd eq "full";
        push @texts, $event->summary() if $cmd eq "summary";
        push @texts, $event->location() if $cmd eq "location";
        push @texts, $event->alarmTime() if $cmd eq "alarm";
        push @texts, $event->startTime() if $cmd eq "start";
        push @texts, $event->endTime() if $cmd eq "end";
      }
    }  
    return join("\n", @texts);
    
  } elsif($cmd eq "find") {

    return "argument is missing" if($#a != 2);
    my $regexp= $a[2];
    my @uids;
    foreach my $event ($eventsObj->events()) {
      push @uids, $event->uid() if($event->summary() =~ m/$regexp/);
    }
    return join(";", @uids);
  
  } else {
    return "Unknown argument $cmd, choose one of text summary full find";
  }

}

#####################################
sub Calendar_Define($$) {

  my ($hash, $def) = @_;

  # define <name> Calendar ical URL [interval]

  my @a = split("[ \t][ \t]*", $def);

  return "syntax: define <name> Calendar ical url <URL> [interval]"
    if(($#a < 4 && $#a > 5) || ($a[2] ne 'ical') || ($a[3] ne 'url'));

  $hash->{STATE} = "Initialized";

  my $name      = $a[0];
  my $url       = $a[4];
  my $interval  = 3600;
  
  $interval= $a[5] if($#a==5);
   
  $hash->{fhem}{url}= $url;
  $hash->{fhem}{interval}= $interval;
  $hash->{fhem}{events}= Calendar::Events->new();

  #main::debug "Interval: ${interval}s";
  $hash->{fhem}{nxtUpdtTs}= 0;
  Calendar_Wakeup($hash);

  return undef;
}

#####################################
sub Calendar_Undef($$) {

  my ($hash, $arg) = @_;

  RemoveInternalTimer($hash);
  return undef;
}

#####################################


#####################################


1;
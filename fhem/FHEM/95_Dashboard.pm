﻿########################################################################################
#
# 95_Dashboard.pm
#
########################################################################################
# Released : 20.12.2013 @svenson08
# Version :
# 1.00: Released to testers
# 1.02: Don't show link on Groups with WebLinks. Hide GroupToogle Button (new Attribut dashboard_showtooglebuttons).
#       Set the Columnheight (new Attribur dashboard_colheight).
# 1.03: Dashboard Entry over the Room-List, set the Room "Dashboard" to hiddenroom. Build weblink independently.
#       Dashboard Row on Top and Bottom (no separately columns). Detail Button
#		to jump into define Detailview. Don't show link on Groups with SVG and readingsGroup.
# 1.04: Sort the Groupentrys (@gemx). Hide Room Dashboard.
# 1.05: Fix dashboard_row center
# 1.10: Released Version 1.10. Rename Module from 95_FWViews to 95_Dashboard. Rename view_* Attributes to
#       dashboard_*. Rename fhemweb_FWViews.js to dashboard.js. Cleanup CSS. Reduce single png-Images to one File only.
#		Fix duplicated run of JS Script. Dashboard STAT show "Missing File" Information if installation is wrong.
# 1.11: use jquery.min and jquery-ui.min. add dashboard_debug attribute. Check dashboard_sorting value plausibility.
#       Change default Values. First Release to FHEM SVN.
# 1.12: Add Germyn command_ref Text. Add Default Values to command_ref (@cotecmania). Fix identification of an existing
#       Dashboard-Weblink (Message *_weblink already defined, delete it first on rereadcfg). Remove white space from 
#		both ends of a group in dashboard_groups. Fix dashboard_sorting check. Wrong added hiddenroom to FHEMWEB 
#		Browsersession fixed. Buttonbar can now placed on top or bottom of the Dashboard (@cotecmania).
#		Dashboard is always edited out the Room Dashboard (@justme1968)
#		Fix Dashboard Entry over the Room-List after 01_FHEMWEB.pm changes
# 2.00: First Changes vor Dashboard Tabs. Change while saving positioning. Alterd max/min Group positioning.
#		Many changes in Dasboard.js. Replaced the attributes dashboard_groups, dashboard_colheight and dashboard_sorting
#		Many new Attributes vor Tabs, Dashboard sizing. Set of mimimal attributes (helpful for beginners).
#		Provisionally the columns widths are dependent on the total width of the Dashboard.
# 2.01: attibute dashboard_colwidth replace with dashboard_rowcentercolwidth. rowcentercolwidth can now be defined per 
#			column. Delete Groups Attribut with Value 1. Dashboard can hide FHEMWEB Roomliste and Header => Fullscreenmode
# 2.02: Tabs can set on top, bottom or hidden. Fix "variable $tabgroups masks earlier" Errorlog.
# 2.03: dashboard_showfullsize only in DashboardRoom. Tabs can show Icons (new Attributes). Fix showhelper Bug on lock/unlock.
#			 The error that after a trigger action the curren tab is changed to the "old" activetab tab has been fixed. dashboard_activetab 
#			 is stored after tab change
#
# Known Bugs/Todos:
# BUG: Nicht alle Inhalte aller Tabs laden, bei Plots dauert die bedienung des Dashboards zu lange. -> elemente hidden?
# x BUG: wenn ich mehrere Tabs habe und zb. im Uten Tab eine Lampe schalte, springt er danach direkt in den ersten Tab. Finde ich etwas unglücklich.
# x BUG: Lock blendet schow helper nicht aus?
# x BUG: dashboard_showfullsize nicht in room everything
# x TODO: Icon on Tabs
# Log 1, "[DASHBOARD simple debug] '".$g."' ";
########################################################################################
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
########################################################################################
# Helpfull Links:
# http://jquery.10927.n7.nabble.com/saving-portlet-state-td125831.html
# http://jsfiddle.net/w7ZvQ/
# http://jsfiddle.net/adamboduch/e6zdX/1/
# http://www.innovativephp.com/jquery-resizable-practical-examples-and-demos/
# http://jsfiddle.net/raulfernandez/mAuxn/
# http://jsfiddle.net/zeTP8/

package main;

use strict;
use warnings;

use vars qw($FW_dir);       # base directory for web server
use vars qw($FW_icondir);   # icon base directory
use vars qw($FW_room);      # currently selected room
use vars qw(%defs);		    # FHEM device/button definitions
use vars qw($FW_wname);     # Web instance
use vars qw(%FW_hiddenroom);# hash of hidden rooms, used by weblink
use vars qw(%FW_types);     # device types

# --------------------------- Global Variable -----------------------------------------------
my %group;
my $fwjquery = "jquery.min.js";
my $fwjqueryui = "jquery-ui.min.js";
my $dashboardname = "Dashboard"; # Link Text
my $dashboardhiddenroom = "DashboardRoom"; # Hiddenroom
my $dashboardversion = "2.03";
# -------------------------------------------------------------------------------------------

sub Dashboard_Initialize ($) {
  my ($hash) = @_;
		
  $hash->{DefFn}       = "Dashboard_define";
  $hash->{UndefFn}     = "Dashboard_undef";
  #$hash->{FW_detailFn} = "Dashboard_detailFn";    
  $hash->{AttrFn}      = "Dashboard_attr";
  $hash->{AttrList}    = "disable:0,1 ".
  						 "dashboard_colcount:1,2,3,4,5 ".						 						 
						 "dashboard_debug:0,1 ".						 
						 "dashboard_lockstate:unlock,lock ".
						 "dashboard_rowtopheight ".
						 "dashboard_rowbottomheight ".
						 "dashboard_row:top,center,bottom,top-center,center-bottom,top-center-bottom ".						 
						 "dashboard_showhelper:0,1 ".
						 "dashboard_showtooglebuttons:0,1 ".						 
						 #new attribute vers. 2.00
						 "dashboard_tabcount:1,2,3,4,5 ".
						 "dashboard_activetab:1,2,3,4,5 ".						 
						 "dashboard_tab1name ".
						 "dashboard_tab2name ".
						 "dashboard_tab3name ".
						 "dashboard_tab4name ".
						 "dashboard_tab5name ".
						 "dashboard_tab1groups ".
						 "dashboard_tab2groups ".
						 "dashboard_tab3groups ".
						 "dashboard_tab4groups ".
						 "dashboard_tab5groups ".						 
						 "dashboard_tab1sorting ".
						 "dashboard_tab2sorting ".
						 "dashboard_tab3sorting ".
						 "dashboard_tab4sorting ".
						 "dashboard_tab5sorting ".						 
						 "dashboard_width ".
						 "dashboard_rowcenterheight ".
						 #new attribute vers. 2.01
						 "dashboard_rowcentercolwidth ".
						 "dashboard_showfullsize:0,1 ".
						 #new attribute vers. 2.02
						 "dashboard_showtabs:tabs-and-buttonbar-at-the-top,tabs-at-the-top-buttonbar-hidden,tabs-and-buttonbar-on-the-bottom,tabs-on-the-bottom-buttonbar-hidden,tabs-and-buttonbar-hidden ".
						 #new attribute vers. 2.03
						 "dashboard_tab1icon ".
						 "dashboard_tab2icon ".
						 "dashboard_tab3icon ".
						 "dashboard_tab4icon ".
						 "dashboard_tab5icon ".
						 
						 #obsolete - erase in future releases
						 "dashboard_groups ". # obsolet -> erase in future releases
						 "dashboard_colheight ". # obsolet -> erase in future releases
						 "dashboard_sorting ". # obsolet -> erase in future releases
						 "dashboard_colwidth ". # obsolet -> erase in future releases
						 "dashboard_showbuttonbar:dont-use-this-attribute ". # obsolet -> erase in future releases
						 
						 $readingFnAttributes;					  

  			 
  $data{FWEXT}{Dashboardx}{LINK} = "?room=".$dashboardhiddenroom;
  $data{FWEXT}{Dashboardx}{NAME} = $dashboardname;	
	
  return undef;
}

sub DashboardAsHtml($)
{
 my ($d) = @_;
 
 my $ret = "";
 my $showbuttonbar = "hidden";
 my $debugfield = "hidden";
 
 my $h = $defs{$d};
 my $name = $defs{$d}{NAME};
 my $id = $defs{$d}{NR};
 
 ######################### Read Dashboard Attributes and set Default-Values ####################################
 my $disable = AttrVal($defs{$d}{NAME}, "disable", 0);
 my $colcount = AttrVal($defs{$d}{NAME}, "dashboard_colcount", 1);
 my $colwidth = AttrVal($defs{$d}{NAME}, "dashboard_rowcentercolwidth", 100);
 my $colheight = AttrVal($defs{$d}{NAME}, "dashboard_rowcenterheight", 400); 
 my $rowtopheight = AttrVal($defs{$d}{NAME}, "dashboard_rowtopheight", 250);
 my $rowbottomheight = AttrVal($defs{$d}{NAME}, "dashboard_rowbottomheight", 250); 
 my $showhelper = AttrVal($defs{$d}{NAME}, "dashboard_showhelper", 1);
 my $showtabs = AttrVal($defs{$d}{NAME}, "dashboard_showtabs", "tabs-and-buttonbar-at-the-top"); 
 my $showtooglebuttons = AttrVal($defs{$d}{NAME}, "dashboard_showtooglebuttons", 1); 
 my $showfullsize  = AttrVal($defs{$d}{NAME}, "dashboard_showfullsize", 0); 
 
 my $row = AttrVal($defs{$d}{NAME}, "dashboard_row", "center");
 my $debug = AttrVal($defs{$d}{NAME}, "dashboard_debug", "0");
 my $lockstate = AttrVal($defs{$d}{NAME}, "dashboard_lockstate", "unlock");
 
 my $activetab = AttrVal($defs{$d}{NAME}, "dashboard_activetab", 1); 
 my $tabcount = AttrVal($defs{$d}{NAME}, "dashboard_tabcount", 1);  
 my $dbwidth = AttrVal($defs{$d}{NAME}, "dashboard_width", "100%"); 
 my @tabnames = (AttrVal($defs{$d}{NAME}, "dashboard_tab1name", "Dashboard-Tab 1"), 
							   AttrVal($defs{$d}{NAME}, "dashboard_tab2name", "Dashboard-Tab 2"),
							   AttrVal($defs{$d}{NAME}, "dashboard_tab3name", "Dashboard-Tab 3"),
							   AttrVal($defs{$d}{NAME}, "dashboard_tab4name", "Dashboard-Tab 4"),
							   AttrVal($defs{$d}{NAME}, "dashboard_tab5name", "Dashboard-Tab 5"));
 my @tabgroups = (AttrVal($defs{$d}{NAME}, "dashboard_tab1groups", ""), 
							   AttrVal($defs{$d}{NAME}, "dashboard_tab2groups", ""),
							   AttrVal($defs{$d}{NAME}, "dashboard_tab3groups", ""),
							   AttrVal($defs{$d}{NAME}, "dashboard_tab4groups", ""),
							   AttrVal($defs{$d}{NAME}, "dashboard_tab5groups", ""));			
 my @tabsortings = (AttrVal($defs{$d}{NAME}, "dashboard_tab1sorting", ""), 
							   AttrVal($defs{$d}{NAME}, "dashboard_tab2sorting", ""),
							   AttrVal($defs{$d}{NAME}, "dashboard_tab3sorting", ""),
							   AttrVal($defs{$d}{NAME}, "dashboard_tab4sorting", ""),
							   AttrVal($defs{$d}{NAME}, "dashboard_tab5sorting", ""));							   
 my @tabicons = (AttrVal($defs{$d}{NAME}, "dashboard_tab1icon", ""),
							AttrVal($defs{$d}{NAME}, "dashboard_tab2icon", ""),
							AttrVal($defs{$d}{NAME}, "dashboard_tab3icon", ""),
							AttrVal($defs{$d}{NAME}, "dashboard_tab4icon", ""),
							AttrVal($defs{$d}{NAME}, "dashboard_tab5icon", ""));
							   
 #############################################################################################

 #---------------- Dashboard is always edited out the Room Dashboard -------------------------
 if ($FW_room ne $dashboardhiddenroom) { 	
#	if ($showbuttonbar eq "hidden") {$showbuttonbar = "top" };   #Dashboard is always edited out the Room Dashboard 
#	$showhelper = 1;																		#Dashboard is always edited out the Room Dashboard 
#	$showtooglebuttons = 1																#Dashboard is always edited out the Room Dashboard 
#	$lockstate = "unlock";																	#Dashboard is always edited out the Room Dashboard 

	$showfullsize = 0;	# Fullsize only in Dashboardroom
 }
 ################ temp. deaktiviert
 #---------------------------------------------------------------------------- 
  
 if ($disable == 1) { 
	$defs{$d}{STATE} = "disabled"; 
	return $ret;
 }
 unless (@tabgroups) { 
	$defs{$d}{STATE} = "No Groups set"; 
	return $ret;
 }
 
 if ($debug == 1) { $debugfield = "edit" }; 
 if ($showtabs eq "tabs-and-buttonbar-at-the-top") { $showbuttonbar = "top"; }
 if ($showtabs eq "tabs-and-buttonbar-on-the-bottom") { $showbuttonbar = "bottom"; }
 if ($showbuttonbar eq "hidden") { $lockstate = "lock" };
 
 if ($activetab > $tabcount) { $activetab = $tabcount; }

 $colwidth =~ tr/,/:/;
 #if ($colwidth =~/[a-zA-Z]+$/) { Log 1, "[DASHBOARD simple debug] Nicht nur zahlen ".$colwidth; } #future release

 if (not ($colheight =~ /^\d+$/)) { $colheight = 400 };  
 if (not ($rowtopheight =~ /^\d+$/)) { $rowtopheight = 50 };
 if (not ($rowbottomheight =~ /^\d+$/)) { $rowbottomheight = 50 };  
 
 #------------------- Check dashboard_sorting on false content ------------------------------------
 for (my $i=0;$i<@tabsortings;$i++){ 
	if (($tabsortings[$i-1] !~ /[0-9]/ || $tabsortings[$i-1] !~ /:/ || $tabsortings[$i-1] !~ /,/  ) && ($tabsortings[$i-1] ne "," && $tabsortings[$i-1] ne "")){
		Log3 $d, 3, "[".$name." V".$dashboardversion."] Value of attribut dashboard_tab".$i."sorting is wrong. Saved sorting can not be set. Fix Value or delete the Attribute. [".$tabsortings[$i-1]."]";	
	} else { Log3 $d, 5, "[".$name." V".$dashboardversion."] Sorting OK or Empty: dashboard_tab".$i."sorting "; }	
 }
 #-------------------------------------------------------------------------------------------------
 
 $ret .= "<table class=\"roomoverview dashboard\" id=\"dashboard\">\n";
 
 $ret .= "<tr><td><div class=\"dashboardhidden\">\n"; 
 $ret .= "<input type=\"$debugfield\" size=\"100%\" id=\"dashboard_attr\" value=\"$name,$dbwidth,$showhelper,$lockstate,$showbuttonbar,$colheight,$showtooglebuttons,$colcount,$rowtopheight,$rowbottomheight,$tabcount,$activetab,$colwidth,$showfullsize\">\n";
 $ret .= "<input type=\"$debugfield\" size=\"100%\" id=\"dashboard_jsdebug\" value=\"\">\n";
 $ret .= "</div></td></tr>\n"; 
 $ret .= "<tr><td><div id=\"tabs\" class=\"dashboard_tabs\">\n";  
 
 ########################### Dashboard Tab-Liste ##############################################
 my $tabshow = "hidden";	
 my $tabicon = "";
 if ($showtabs eq "tabs-and-buttonbar-at-the-top" || $showtabs eq "tabs-at-the-top-buttonbar-hidden") { $tabshow = "top";}
 if ($showtabs eq "tabs-and-buttonbar-on-the-bottom" || $showtabs eq "tabs-on-the-bottom-buttonbar-hidden") { $tabshow = "bottom";}
	
 $ret .= "	<ul id=\"dashboard_tabnav\" class=\"dashboard_tabnav dashboard_tabnav_".$tabshow."\">\n";	 
 if ($showtabs ne "tabs-at-the-top-buttonbar-hidden" &&  $showtabs ne "tabs-on-the-bottom-buttonbar-hidden" && $showtabs ne "tabs-and-buttonbar-hidden") { $ret .= BuildButtonBar($d,$showtabs); }
  for (my $i=0;$i<$tabcount;$i++){ 
	$tabicon = ""; 
	if ($tabicons[$i] ne "") { $tabicon = FW_makeImage($tabicons[$i],$tabicons[$i],"dashboard_tabicon") . "&nbsp;"; }
    $ret .= "    <li class=\"dashboard_tab dashboard_tab_".$tabshow."\">".$tabicon."<a href=\"#dashboard_tab".$i."\">".trim($tabnames[$i])."</a></li>"; 
 } 
 $ret .= "	</ul>\n"; 
 ##############################################################################################
 
 for (my $t=0;$t<$tabcount;$t++){ 
	my @tabgroup = split(",", $tabgroups[$t]); #Set temp. position for groups without an stored position
	for (my $i=0;$i<@tabgroup;$i++){
		if (index($tabsortings[$t],trim($tabgroup[$i])) < 0) { $tabsortings[$t] = $tabsortings[$t]."t".$t."c".GetMaxColumnId($row,$colcount).",".trim($tabgroup[$i]).",true,0,0:"; }
	}	
	%group = BuildGroupList($tabgroups[$t]);	 
	$ret .= "	<div id=\"dashboard_tab".$t."\" data-tabwidgets=\"".$tabsortings[$t]."\" class=\"dashboard_tabpanel\">\n";
	$ret .= "   <ul class=\"dashboard_tabcontent\">\n";
	$ret .= "	<table class=\"dashboard_tabcontent\">\n";	# dashboard\">";	 
		##################### Top Row (only one Column) #############################################
		if ($row eq "top-center-bottom" || $row eq "top-center" || $row eq "top"){ $ret .= BuildDashboardTopRow($t,$id,$tabgroups[$t],$tabsortings[$t]); }		
		##################### Center Row (max. 5 Column) ############################################
		if ($row eq "top-center-bottom" || $row eq "top-center" || $row eq "center-bottom" || $row eq "center"){ $ret .= BuildDashboardCenterRow($t,$id,$tabgroups[$t],$tabsortings[$t],$colcount);} 
		############################# Bottom Row (only one Column) ############################################
		if ($row eq "top-center-bottom" || $row eq "center-bottom" || $row eq "bottom"){ $ret .= BuildDashboardBottomRow($t,$id,$tabgroups[$t],$tabsortings[$t]); }
		#############################################################################################	 
	 $ret .= "	</table>\n";
	 $ret .= " 	</ul>\n";
	 $ret .= "	</div>\n"; 
 }
 $ret .= "</div></td></tr>\n";
 $ret .= "</table>\n";
 
 return $ret; 
}

sub BuildDashboardTopRow($$$$){
 my ($t,$id, $dbgroups, $dbsorting) = @_;
 my $ret; 
 $ret .= "<tr><td>\n";
 $ret .= "<div id=\"dashboard_rowtop_tab".$t."\" class=\"dashboard_rowtop\">\n";
 $ret .= "		<div class=\"ui-row dashboard_row dashboard_column\" id=\"dashboard_tab".$t."column100\">\n";
 $ret .= BuildGroupWidgets($t,"100",$id,$dbgroups,$dbsorting); 
 $ret .= "		</div>\n";
 $ret .= "</div>\n";
 $ret .= "</td></tr>\n";
 return $ret;
}

sub BuildDashboardCenterRow($$$$$){
 my ($t,$id, $dbgroups, $dbsorting, $colcount) = @_;
 my $ret; 
 $ret .= "<tr><td>\n";
 $ret .= "<div id=\"dashboard_rowcenter_tab".$t."\" class=\"dashboard_rowcenter\">\n";

 for (my $i=0;$i<$colcount;$i++){
	$ret .= "		<div class=\"ui-row dashboard_row dashboard_column\" id=\"dashboard_tab".$t."column".$i."\">\n";
	$ret .= BuildGroupWidgets($t,$i,$id,$dbgroups,$dbsorting); 
	$ret .= "		</div>\n";
 }
 $ret .= "</div>\n";
 $ret .= "</td></tr>\n";
 return $ret;
}

sub BuildDashboardBottomRow($$$$){
 my ($t,$id, $dbgroups, $dbsorting) = @_;
 my $ret; 
 $ret .= "<tr><td>\n";
 $ret .= "<div id=\"dashboard_rowbottom_tab".$t."\" class=\"dashboard_rowbottom\">\n";
 $ret .= "		<div class=\"ui-row dashboard_row dashboard_column\" id=\"dashboard_tab".$t."column200\">\n";
 $ret .= BuildGroupWidgets($t,"200",$id,$dbgroups,$dbsorting); 
 $ret .= "		</div>\n";
 $ret .= "</div>\n";
 $ret .= "</td></tr>\n";
 return $ret;
}

sub BuildButtonBar($$){
 my ($d,$pos) = @_;
 my $ret = "";
 my $cssclass = "hidden";
 
 if ($pos eq "tabs-and-buttonbar-at-the-top") { $cssclass = "top"; }
 if ($pos eq "tabs-and-buttonbar-on-the-bottom") { $cssclass = "bottom"; }
 
 if ($pos ne "hidden") {
	 $ret .= "<div class=\"dashboard_buttonbar dashboard_buttonbar_".$cssclass."\">\n";
	 $ret .= "	<div class=\"dashboard_button\"> <span class=\"dashboard_button_icon dashboard_button_iconset\"></span> <a id=\"dashboard_button_set\" href=\"javascript:dashboard_setposition()\" title=\"Set the Position\">Set</a> </div>\n";
	 $ret .= "	<div class=\"dashboard_button\"> <a id=\"dashboard_button_lock\" href=\"javascript:dashboard_tooglelock()\" title=\"Lock Dashboard\">Lock</a> </div>\n";
	 $ret .= "	<div class=\"dashboard_button\"> <span class=\"dashboard_button_icon dashboard_button_icondetail\"></span> <a id=\"dashboard_button_detail\" href=\"/fhem?detail=$d\" title=\"Dashboard Details\">Detail</a> </div>\n";		
	 $ret .= "</div>\n";
 }
 return $ret;
}

sub BuildGroupWidgets($$$$$) {
 my ($tab,$column,$id,$dbgroups, $dbsorting) = @_;
 my $ret = "";
 
 		my $counter = 0;
		my @storedsorting = split(":", $dbsorting);
		foreach my $singlesorting (@storedsorting) {
			my @groupdata = split(",", $singlesorting);		
			if (index($dbsorting, "t".$tab."c".$column.",".$groupdata[1]) >= 0  && index($dbgroups, $groupdata[1]) >= 0 && $groupdata[1] ne "" ) { #gruppe auch für tab hinterlegt
				$ret .= "  <div class=\"dashboard_widget\" data-groupwidget=\"".$singlesorting."\" id=\"".$id."t".$tab."c".$column."w".$counter."\">\n";
				$ret .= "   <div class=\"dashboard_widgetinner\">\n";	
				$ret .= "    <div class=\"dashboard_widgetheader\">".$groupdata[1]."</div>\n";
				$ret .= "    <div data-userheight=\"\" class=\"dashboard_content\">\n";
				$ret .= BuildGroup($groupdata[1]);
				$ret .= "    </div>\n";	
				$ret .= "   </div>\n";	
				$ret .= "  </div>\n";	
				$counter++;
			}
		}
 
 return $ret; 
}

sub BuildGroupList($) {
 my @dashboardgroups = split(",", $_[0]); #array for all groups to build an widget
 my %group = ();
 
 foreach my $d (sort keys %defs) {
    foreach my $grp (split(",", AttrVal($d, "group", ""))) {
		$grp = trim($grp);
		foreach my $g (@dashboardgroups){ 
			$g = trim($g);
			$group{$grp}{$d} = 1 if($g eq $grp); 
		}
    }
 } 
 return %group;
}  

sub BuildGroup($)
{
 my ($currentgroup) = @_;
 my $ret = ""; 
 my $row = 1;
 my %extPage = ();
 
 my $rf = ($FW_room ? "&amp;room=$FW_room" : ""); # stay in the room

 foreach my $g (keys %group) {

	next if ($g ne $currentgroup);
	$ret .= "<table class=\"block wide\" id=\"TYPE_$currentgroup\">";
	foreach my $d (sort keys %{$group{$g}}) {
		$ret .= sprintf("<tr class=\"%s\">", ($row&1)?"odd":"even");
		
		my $type = $defs{$d}{TYPE};
		my $devName = AttrVal($d, "alias", $d);
		my $icon = AttrVal($d, "icon", "");
		$icon = FW_makeImage($icon,$icon,"icon dashboard_groupicon") . "&nbsp;" if($icon);
	
		if($FW_hiddenroom{detail}) { $ret .= "<td><div class=\"col1\">$icon$devName</div></td>"; } 
		else { 
			if ($type ne "weblink" && $type ne "SVG" && $type ne "readingsGroup") { # Don't show Link by weblink, svg and readingsGroup
				$ret .=FW_pH "detail=$d", "$icon$devName", 1, "col1", 1; 
			}			
		}
		$row++;		
			
		my ($allSets, $cmdlist, $txt) = FW_devState($d, $rf, \%extPage);
		$ret .= "<td informId=\"$d\">$txt</td>";

		###### Commands, slider, dropdown
        if(!$FW_ss && $cmdlist) {
			foreach my $cmd (split(":", $cmdlist)) {
				my $htmlTxt;
				my @c = split(' ', $cmd);
				if($allSets && $allSets =~ m/$c[0]:([^ ]*)/) {
					my $values = $1;
					foreach my $fn (sort keys %{$data{webCmdFn}}) {
						no strict "refs";
						$htmlTxt = &{$data{webCmdFn}{$fn}}($FW_wname, $d, $FW_room, $cmd, $values);
						use strict "refs";
						last if(defined($htmlTxt));
					}
				}
				if($htmlTxt) {
					$ret .= $htmlTxt;
				} else {
				  $ret .=FW_pH "cmd.$d=set $d $cmd$rf", $cmd, 1, "col3", 1;
				}
			}
		}
		$ret .= "</tr>";
	}
	$ret .= "</table>";
 }
 if ($ret eq "") { 
	$ret .= "<table class=\"block wide\" id=\"TYPE_unknowngroup\">";
	$ret .= "<tr class=\"odd\"><td class=\"changed\">Unknown Group: $currentgroup</td></tr>";
	$ret .= "<tr class=\"even\"><td class=\"changed\">Check if the group attribute is really set</td></tr>";
	$ret .= "<tr class=\"odd\"><td class=\"changed\">Check if the groupname is correct written</td></tr>";
	$ret .= "</table>"; 	
 }
 return $ret;
}

sub GetMaxColumnId($$) {
	my ($row, $colcount) = @_;
	my $maxcolid = "0";
	
	if (index($row,"bottom") > 0) { $maxcolid = "200"; } 
	elsif (index($row,"center") > 0) { $maxcolid = $colcount-1; } 
	elsif (index($row,"top") > 0) { $maxcolid = "100"; }
	return $maxcolid;
}

sub CheckInstallation($) {
 my ($hash) = @_;

 unless (-e $FW_dir."/pgm2/".$fwjquery) {
	Log3 $hash, 3, "[".$hash->{NAME}. " V".$dashboardversion."] Missing File ".$FW_dir."/pgm2/".$fwjquery;
	$hash->{STATE} = 'Missing File, see LogFile for Details';
 } 
 unless (-e $FW_dir."/pgm2/".$fwjqueryui) {
	Log3 $hash, 3, "[".$hash->{NAME}. " V".$dashboardversion."] Missing File ".$FW_dir."/pgm2/".$fwjqueryui;
	$hash->{STATE} = 'Missing File, see LogFile for Details';
 } 
 unless (-e $FW_dir."/pgm2/dashboard.js") {
	Log3 $hash, 3, "[".$hash->{NAME}. " V".$dashboardversion."] Missing File ".$FW_dir."/pgm2/dashboard.js";
	$hash->{STATE} = 'Missing File, see LogFile for Details';
 }  
 unless (-e $FW_icondir."/default/dashboardicons.png") {
	Log3 $hash, 3, "[".$hash->{NAME}. " V".$dashboardversion."] Missing File ".$FW_icondir."/default/dashboardicons.png";
	$hash->{STATE} = 'Missing File, see LogFile for Details';
 }  
}

sub CheckDashboardEntry($) {
	my ($hash) = @_;
	my $now = time();
	my $timeToExec = $now + 5;
	
	RemoveInternalTimer($hash);
	InternalTimer      ($timeToExec, 'CreateDashboardEntry', $hash, 0);
	InternalTimer      ($timeToExec, 'CheckDashboardAttributUssage', $hash, 0);
}

sub CheckDashboardAttributUssage($) { # replaces old disused attributes and their values | set minimal attributes
 my ($hash) = @_;
 my $d = $hash->{NAME};
 my $detailnote = "";
 
 # --------- Set minimal Attributes in the hope to make it easier for beginners --------------------
 my $tabcount = AttrVal($defs{$d}{NAME}, "dashboard_tabcount", "0");
 if ($tabcount eq "0") { FW_fC("attr ".$d." dashboard_tabcount 1"); }
 my $tab1groups = AttrVal($defs{$d}{NAME}, "dashboard_tab1groups", "<noGroup>");
 if ($tab1groups eq "<noGroup>") { FW_fC("attr ".$d." dashboard_tab1groups Set Your Groups - See Attribute dashboard_tab1groups-"); }
 # ------------------------------------------------------------------------------------------------- 
 # ---------------- Delete empty Groups entries ---------------------------------------------------------- 
 my $tabgroups = AttrVal($defs{$d}{NAME}, "dashboard_tab1groups", "999");
 if ($tabgroups eq "1"  ) { FW_fC("deleteattr ".$d." dashboard_tab1groups"); }
 $tabgroups = AttrVal($defs{$d}{NAME}, "dashboard_tab2groups", "999");
 if ($tabgroups eq "1"  ) { FW_fC("deleteattr ".$d." dashboard_tab2groups"); } 
 $tabgroups = AttrVal($defs{$d}{NAME}, "dashboard_tab3groups", "999");
 if ($tabgroups eq "1"  ) { FW_fC("deleteattr ".$d." dashboard_tab3groups"); }  
 $tabgroups = AttrVal($defs{$d}{NAME}, "dashboard_tab4groups", "999");
 if ($tabgroups eq "1"  ) { FW_fC("deleteattr ".$d." dashboard_tab4groups"); }   
 $tabgroups = AttrVal($defs{$d}{NAME}, "dashboard_tab5groups", "999");
 if ($tabgroups eq "1"  ) { FW_fC("deleteattr ".$d." dashboard_tab5groups"); }   
 # -------------------------------------------------------------------------------------------------
  
 # ---- detached / transferred from the old attribute to the tab extension (outdated 02.2014) ------
 my $colwidth = AttrVal($defs{$d}{NAME}, "dashboard_colwidth", "");
 if ($colwidth ne "") {
	{ FW_fC("attr ".$d." dashboard_rowcentercolwidth ".$colwidth); }
	{ FW_fC("deleteattr ".$d." dashboard_colwidth"); }
	$detailnote = $detailnote." [dashboard_colwidth -> dashboard_rowcentercolwidth]"; 
 } 
 my $colheight = AttrVal($defs{$d}{NAME}, "dashboard_colheight", "");
 if ($colheight ne "") {
	{ FW_fC("attr ".$d." dashboard_rowcenterheight ".$colheight); }
	{ FW_fC("deleteattr ".$d." dashboard_colheight"); }
	$detailnote = $detailnote." [dashboard_colheight -> dashboard_rowcenterheight]";
 }
 my $groups = AttrVal($defs{$d}{NAME}, "dashboard_groups", "");
 if ($groups ne "") {
	{ FW_fC("attr ".$d." dashboard_tab1groups ".$groups); }
	{ FW_fC("deleteattr ".$d." dashboard_groups"); }
	$detailnote = $detailnote." [dashboard_groups -> dashboard_tab1groups]";
 } 
 my $sorting = AttrVal($defs{$d}{NAME}, "dashboard_sorting", "");
 if ($sorting ne "") { #convert old sorting in new 
	my @sortings = split(":", $sorting);
	my $newsorting = "";
	my $groupcounter = 0;
	for (my $s=0;$s<@sortings;$s++){	#0,590w3,true,246,826, 590w0,true,183,258:
		my @groups = split(",", $sortings[$s]);
		for (my $g=1;$g<@groups;$g+=4){			
			my $row = AttrVal($defs{$d}{NAME}, "dashboard_row", "center");
			my $colcount = AttrVal($defs{$d}{NAME}, "dashboard_colcount", "1");
			my @dbgroups = split(",", AttrVal($defs{$d}{NAME}, "dashboard_tab1groups", ",")); #1. gruppeneintrag = 1. gespeicherte gruppe
			my @dbgroup = split("w",$groups[$g]);
			my $column = "";
			#Map old Column Count to new Count			
			if ($row eq "top" && $groups[0] == 0) { $column = "t0c100"; }
			if ($row eq "center") { $column = "t0c".$groups[0]; }			
			if ($row eq "bottom" && $groups[0] == 0) { $column = "200"; }
			if ($row eq "top-center" && $groups[0] == 0) { $column = "t0c100"; }
			if ($row eq "top-center" && $groups[0] != 0) { $column = "t0c".($groups[0]-1); }
			if ($row eq "center-bottom" && $groups[0] <= $colcount-1) { $column = "t0c".$groups[0]; }
			if ($row eq "center-bottom" && $groups[0] > $colcount-1) { $column = "t0c200"; }
			if ($row eq "top-center-bottom" && $groups[0] == "0") { $column = "t0c100"; }
			if ($row eq "top-center-bottom" && $groups[0] != 0 && $groups[0] <= $colcount) { $column = "t0c".($groups[0]-1); }
			if ($row eq "top-center-bottom" && $groups[0] > $colcount) { $column = "t0c200"; }			
			$newsorting = $newsorting.$column.",".$dbgroups[$dbgroup[1]].",".$groups[$g+1].",".$groups[$g+3].",".$groups[$g+2].":";
			$groupcounter = $groupcounter +1;
		}		
	}
	{ FW_fC("attr ".$d." dashboard_tab1sorting ".$newsorting); }
	{ FW_fC("deleteattr ".$d." dashboard_sorting"); }
	$detailnote = $detailnote." [dashboard_sorting -> dashboard_tab1sorting]";
 }
 # ------------------------------------------------------------------------------------------------------------------------ 
 
 # ---- detached / transferred from the old attribute to the tab extension (outdated 02.2014) ------ 
 my $buttonbar = AttrVal($defs{$d}{NAME}, "dashboard_showbuttonbar", ""); 
 if ($buttonbar ne "") { 
	FW_fC("deleteattr ".$d." dashboard_showbuttonbar"); 
	$detailnote = $detailnote." [dashboard_showbuttonbar]";
 }
 # ------------------------------------------------------------------------------------------------------------------------ 

 # Get out any change to the Logfile 
 if ($buttonbar ne "" || $groups ne "" || $sorting ne "") {   
  Log3 $hash, 3, "[".$hash->{NAME}. " V".$dashboardversion."]"." Using an outdated no longer used Attribute or Value. This has been corrected. Don't forget to save config. ".$detailnote; 
 }
}

sub CreateDashboardEntry($) {
 my ($hash) = @_;
 
 my $h = $hash->{NAME};
 if (!defined $defs{$h."_weblink"}) {
	FW_fC("define ".$h."_weblink weblink htmlCode {DashboardAsHtml(\"".$h."\")}");
	Log3 $hash, 3, "[".$hash->{NAME}. " V".$dashboardversion."]"." Weblink dosen't exists. Created weblink ".$h."_weblink. Don't forget to save config.";
 }
 FW_fC("attr ".$h."_weblink room ".$dashboardhiddenroom);

 foreach my $dn (sort keys %defs) {
  if ($defs{$dn}{TYPE} eq "FHEMWEB" && $defs{$dn}{NAME} !~ /FHEMWEB:/) {
	my $hr = AttrVal($defs{$dn}{NAME}, "hiddenroom", "");
	
	#---------- Delete older Hiddenroom for Dashboard due changes in 01_FHEMWEB.pm (01.2014) ---------
	if (index($hr,$dashboardname) != -1  && index($hr,$dashboardhiddenroom) == -1) { 
	 $hr =~ s/$dashboardname/$dashboardhiddenroom/g;
	 FW_fC("attr ".$defs{$dn}{NAME}." hiddenroom ".$hr);	 
	 Log3 $hash, 3, "[".$hash->{NAME}. " V".$dashboardversion."]"." Corrected hiddenroom '".$dashboardname."' -> '".$dashboardhiddenroom."' in ".$defs{$dn}{NAME}.". Don't forget to save config.";
	}
	#-------------------------------------------------------------------------------------------------
	
	if (index($hr,$dashboardhiddenroom) == -1){ 		
		if ($hr eq "") {FW_fC("attr ".$defs{$dn}{NAME}." hiddenroom ".$dashboardhiddenroom);}
		else {FW_fC("attr ".$defs{$dn}{NAME}." hiddenroom ".$hr.",".$dashboardhiddenroom);}
		Log3 $hash, 3, "[".$hash->{NAME}. " V".$dashboardversion."]"." Added hiddenroom '".$dashboardhiddenroom."' to ".$defs{$dn}{NAME}.". Don't forget to save config.";
	}	
  }
 }
 
} 

sub Dashboard_define ($$) {
 my ($hash, $def) = @_;
 my $name = $hash->{NAME};
 
 $data{FWEXT}{jquery}{SCRIPT} = "/pgm2/".$fwjquery;
 $data{FWEXT}{jqueryui}{SCRIPT} = "/pgm2/".$fwjqueryui;
 $data{FWEXT}{testjs}{SCRIPT} = "/pgm2/dashboard.js";
 $hash->{STATE} = 'Initialized';  
  
 CheckInstallation($hash);
 CheckDashboardEntry($hash);

 return;
}

sub Dashboard_undef ($$) {
  my ($hash,$arg) = @_;
  
  RemoveInternalTimer($hash);
  
  return undef;
}

sub Dashboard_detailFn() {
  my ($name, $d, $room, $pageHash) = @_;
  my $hash = $defs{$name};
  #return DashboardAsHtml($d); #creates confusion and leads to incorrect storage of items
  return; 
}

sub Dashboard_attr($$$) {
  my ($cmd, $name, $attrName, $attrVal) = @_;
  
#if ($cmd eq "set") {
#	$dashboarddata{$attrName} = $attrVal;
#	Log 1, "[DASHBOARD simple debug] ".$attrName." - ".$attrVal;
# }
  return;  
}

1;

=pod
=begin html

<a name="Dashboard"></a>
<h3>Dashboard</h3>
<ul>
  Creates a Dashboard in any group can be arranged. The positioning may depend the Groups and column width are made<br>
  arbitrarily by drag'n drop. Also, the width and height of a Group can be increased beyond the minimum size.<br>
  <br> 
  
  <a name="Dashboarddefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; Dashboard</code>
	<br><br>
    Example:<br>
    <ul>
     <code>define anyViews Dashboard</code>
    </ul><br>
	
  <b>Bestpractice beginner configuration</b>
	<br><br>
	<code>
	define anyViews Dashboard<br>
	attr anyViews dashboard_colcount 2<br>
	attr anyViews dashboard_rowcentercolwidth 30,70<br>
	attr anyViews dashboard_tab1groups &lt;Group1&gt;,&lt;Group2&gt;,&lt;Group3&gt;<br>
	attr anyViews dashboard_lockstate unlock<br>
	attr anyViews dashboard_showhelper 1<br>
	</code>	
  </ul>
  <br>

  <a name="Dashboardset"></a>
  <b>Set</b> 
  <ul>
	N/A
  </ul>
  <br>
  
  <a name="Dashboardget"></a>
  <h4>Get</h4> <ul>N/A</ul><br>
  <a name="Dashboardattr"></a>
  <h4>Attributes</h4> 
  
  <a name="dashboard_tabcount"></a>
    <li>dashboard_tabcount<br>
		Returns the number of displayed tabs.
		Default: 1
    </li><br>	  
  <a name="dashboard_activetab"></a>
    <li>dashboard_activetab<br>
		Specifies which tab is activated. Can be set manually, but is also set by the switch "Set" to the currently active tab.
		Default: 1
    </li><br>	 
  <a name="dashboard_tab1name"></a>
    <li>dashboard_tab1name<br>
		Title of Tab 1.
		Default: Dashboard-Tab 1
    </li><br>	   
  <a name="dashboard_tab2name"></a>
    <li>dashboard_tab2name<br>
		Title of Tab 2.
		Default: Dashboard-Tab 2
    </li><br>	    
   <a name="dashboard_tab3name"></a>
    <li>dashboard_tab3name<br>
		Title of Tab 3.
		Default: Dashboard-Tab 3
    </li><br>	 
   <a name="dashboard_tab4name"></a>
    <li>dashboard_tab4name<br>
		Title of Tab 4.
		Default: Dashboard-Tab 4
    </li><br>	 
   <a name="dashboard_tab5name"></a>
    <li>dashboard_tab5name<br>
		Title of Tab 5.
		Default: Dashboard-Tab 5
    </li><br>		
  <a name="dashboard_sorting"></a>	
    <li>dashboard_sorting<br>
		This attribute is no longer used and will be removed at a later date. It was replaced with <br>
		dashboard_tab1sorting, dashboard_tab2sorting, dashboard_tab3sorting, dashboard_tab4sorting, dashboard_tab5sorting
    </li><br>	
  <a name="dashboard_tab1sorting"></a>	
    <li>dashboard_tab1sorting<br>
        Contains the position of each group in Tab 1. Value is written by the "Set" button. It is not recommended to take manual changes.
    </li><br>		
  <a name="dashboard_tab2sorting"></a>	
    <li>dashboard_tab2sorting<br>
        Contains the position of each group in Tab 2. Value is written by the "Set" button. It is not recommended to take manual changes.
    </li><br>	
  <a name="dashboard_tab3sorting"></a>	
    <li>dashboard_tab3sorting<br>
        Contains the position of each group in Tab 3. Value is written by the "Set" button. It is not recommended to take manual changes.
    </li><br>	
  <a name="dashboard_tab4sorting"></a>	
    <li>dashboard_tab4sorting<br>
        Contains the position of each group in Tab 4. Value is written by the "Set" button. It is not recommended to take manual changes.
    </li><br>	
  <a name="dashboard_tab5sorting"></a>	
    <li>dashboard_tab5sorting<br>
        Contains the position of each group in Tab 5. Value is written by the "Set" button. It is not recommended to take manual changes.
    </li><br>			
  <a name="dashboard_row"></a>	
    <li>dashboard_row<br>
        To select which rows are displayed. top only; center only; bottom only; top and center; center and bottom; top,center and bottom.<br>
		Default: center
    </li><br>		
  <a name="dashboard_width"></a>	
    <li>dashboard_width<br>
        To determine the Dashboardwidth. The value can be specified, or an absolute width value (eg 1200) in pixels in% (eg 80%).<br>
		Default: 100%
    </li><br>			
  <a name="dashboard_colwidth"></a>	
    <li>dashboard_colwidth<br>
        This attribute is no longer used and will be removed at a later date. It was replaced with <br>
		dashboard_rowcentercolwidth<br>
		Default: 320
    </li><br>		
  <a name="dashboard_colheight"></a>	
    <li>dashboard_colheight<br>
		This attribute is no longer used and will be removed at a later date. It was replaced with <br>
		dashboard_rowcenterheight
    </li><br>		
  <a name="dashboard_rowcenterheight"></a>	
    <li>dashboard_rowcenterheight<br>
        Height of the center row in which the groups may be positioned. <br> 		
		Default: 400		
    </li><br>			
  <a name="dashboard_rowcentercolwidth"></a>	
    <li>dashboard_rowcentercolwidth<br>
		About this attribute, the width of each column of the middle Dashboardrow can be set. It can be stored for each column a separate value. 
		The values ​​must be separated by a comma (no spaces). Each value determines the column width in%! The first value specifies the width of the first column, 
		the second value of the width of the second column, etc. Is the sum of the width greater than 100 it is reduced. 
		If more columns defined as widths the missing widths are determined by the difference to 100. However, are less columns are defined as the values ​​of 
		ignores the excess values​​.<br>
		Default: 100
    </li><br>			
  <a name="dashboard_rowtopheight"></a>	
    <li>dashboard_rowtopheight<br>
        Height of the top row in which the groups may be positioned. <br>
		Default: 250
    </li><br>		
  <a name="dashboard_rowbottomheight"></a>	
    <li>"dashboard_rowbottomheight<br>
        Height of the bottom row in which the groups may be positioned.<br>
		Default: 250
    </li><br>		
  <a name="dashboard_groups"></a>	
    <li>dashboard_groups<br>
		This attribute is no longer used and will be removed at a later date. It was replaced with <br>
		dashboard_tab1groups, dashboard_tab2groups, dashboard_tab3groups, dashboard_tab4groups, dashboard_tab5groups
    </li><br>			
  <a name="dashboard_tab1groups"></a>	
    <li>dashboard_tab1groups<br>
        Comma-separated list of the names of the groups to be displayed in Tab 1.
    </li><br>		
  <a name="dashboard_tab2groups"></a>	
    <li>dashboard_tab1groups<br>
        Comma-separated list of the names of the groups to be displayed in Tab 2.
    </li><br>			
  <a name="dashboard_tab3groups"></a>	
    <li>dashboard_tab1groups<br>
        Comma-separated list of the names of the groups to be displayed in Tab 3.
    </li><br>		
  <a name="dashboard_tab4groups"></a>	
    <li>dashboard_tab1groups<br>
        Comma-separated list of the names of the groups to be displayed in Tab 4.
    </li><br>			
  <a name="dashboard_tab5groups"></a>	
    <li>dashboard_tab1groups<br>
        Comma-separated list of the names of the groups to be displayed in Tab 5.
    </li><br>	
  <a name="dashboard_tab1icon"></a>	
    <li>dashboard_tab1icon<br>
		Set the icon for a Tab. There must exist an icon with the name ico.png in the modpath directory. If the image is referencing an SVG icon, then you can use the @colorname suffix to color the image. 
    </li><br>
  <a name="dashboard_tab2icon"></a>	
    <li>dashboard_tab2icon<br>
		Set the icon for a Tab. There must exist an icon with the name ico.png in the modpath directory. If the image is referencing an SVG icon, then you can use the @colorname suffix to color the image. 
    </li><br>	
  <a name="dashboard_tab3icon"></a>	
    <li>dashboard_tab3icon<br>
		Set the icon for a Tab. There must exist an icon with the name ico.png in the modpath directory. If the image is referencing an SVG icon, then you can use the @colorname suffix to color the image. 
    </li><br>	
  <a name="dashboard_tab4icon"></a>	
    <li>dashboard_tab4icon<br>
		Set the icon for a Tab. There must exist an icon with the name ico.png in the modpath directory. If the image is referencing an SVG icon, then you can use the @colorname suffix to color the image. 
    </li><br>	
  <a name="dashboard_tab5icon"></a>	
    <li>dashboard_tab5icon<br>
		Set the icon for a Tab. There must exist an icon with the name ico.png in the modpath directory. If the image is referencing an SVG icon, then you can use the @colorname suffix to color the image. 
    </li><br>	
  <a name="dashboard_lockstate"></a>		
    <li>dashboard_lockstate<br>
        When set to "unlock" you can edit the Dashboard. When set to "lock" no change can be made. <br>
		If the bar is hidden dashboard_lockstate is "lock". Editing is possible only with activated switch panel.<br>
		Default: unlock
    </li><br>	
  <a name="dashboard_colcount"></a>	
    <li>dashboard_colcount<br>
        Number of columns in which the groups can be displayed. Nevertheless, it is possible to have multiple groups <br>
		to be positioned in a column next to each other. This is dependent on the width of columns and groups. <br>
		Default: 1
    </li><br>		
 <a name="dashboard_showfullsize"></a>	
    <li>dashboard_showfullsize<br>
		Hide FHEMWEB Roomliste (complete left side) and Page Header if Value is 1.<br>
		Default: 0
    </li><br>		
 <a name="dashboard_showtabs"></a>	
    <li>dashboard_showtabs<br>
		Displays the Tabs on top or bottom, or hides them. This also applies to the Buttonbar. If the Buttonbar is hidden dashboard_lockstate the "lock" is used.<br>
		Default: tabs-and-buttonbar-at-the-top
    </li><br>
 <a name="dashboard_showhelper"></a>		
    <li>dashboard_showhelper<br>
        Displays frames in order to facilitate the positioning of the groups.<br>
		Default: 1
    </li><br>	 
 <a name="dashboard_showtooglebuttons"></a>		
    <li>dashboard_showtooglebuttons<br>
        Displays a Toogle Button on each Group do collapse.<br>
		Default: 1
    </li><br>	
 <a name="dashboard_debug"></a>		
    <li>dashboard_debug<br>
        Show Hiddenfields. Only for Maintainer's use.<br>
		Default: 0
    </li><br>	

</ul>

=end html
=begin html_DE

<a name="Dashboard"></a>
<h3>Dashboard</h3>
<ul>
  Erstellt eine Übersicht in der Gruppen angeordnet werden können. Dabei können die Gruppen mit Drag'n Drop frei positioniert<br>
  und in mehreren Spalten angeordnet werden. Auch kann die Breite und Höhe einer Gruppe über die Mindestgröße hinaus gezogen werden. <br>
  <br> 
  
  <a name="Dashboarddefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; Dashboard</code>
	<br><br>
    Beispiel:<br>
    <ul>
     <code>define anyViews Dashboard</code>
    </ul><br>
	
  <b>Bestpractice Anfängerkonfiguration</b>
	<br><br>
	<code>
	define anyViews Dashboard<br>
	attr anyViews dashboard_colcount 2<br>
	attr anyViews dashboard_rowcentercolwidth 30,70<br>
	attr anyViews dashboard_tab1groups &lt;Group1&gt;,&lt;Group2&gt;,&lt;Group3&gt;<br>
	attr anyViews dashboard_lockstate unlock<br>
	attr anyViews dashboard_showhelper 1<br>
	</code>	
  </ul>
  <br>

  <a name="Dashboardset"></a>
  <b>Set</b> 
  <ul>
	N/A
  </ul>
  <br>
  
  <a name="Dashboardget"></a>
  <h4>Get</h4> <ul>N/A</ul><br>
  <a name="Dashboardattr"></a>
  <h4>Attributes</h4> 
  
  <a name="dashboard_tabcount"></a>	
    <li>dashboard_tabcount<br>
		Gibt die Anzahl der angezeigten Tabs an.
		Default: 1
    </li><br>	  
  <a name="dashboard_activetab"></a>	
	 <li>dashboard_activetab<br>
		Gibt an welches Tab aktiviert ist. Kann manuell gesetzt werden, wird aber auch durch den Schalter "Set" auf das gerade aktive Tab gesetzt.
		Default: 1
    </li><br>	  
  <a name="dashboard_tab1name"></a>
    <li>dashboard_tab1name<br>
		Titel des 1. Tab.
		Default: Dashboard-Tab 1
    </li><br>	   
  <a name="dashboard_tab2name"></a>
    <li>dashboard_tab2name<br>
		Titel des 2. Tab.
		Default: Dashboard-Tab 2
    </li><br>	    
   <a name="dashboard_tab3name"></a>
    <li>dashboard_tab3name<br>
		Titel des 3. Tab.
		Default: Dashboard-Tab 3
    </li><br>	 
   <a name="dashboard_tab4name"></a>
    <li>dashboard_tab4name<br>
		Titel des 4. Tab.
		Default: Dashboard-Tab 4
    </li><br>	 
   <a name="dashboard_tab5name"></a>
    <li>dashboard_tab5name<br>
		Titel des 5. Tab.
		Default: Dashboard-Tab 5
    </li><br>	
  <a name="dashboard_sorting"></a>	
    <li>dashboard_sorting<br>
		Dieses Attribut ist nicht mehr zu verwenden und wird zu einem späteren Zeitpunkt entfernt. Es wurde ersetzt durch <br>
		dashboard_tab1sorting, dashboard_tab2sorting, dashboard_tab3sorting, dashboard_tab4sorting, dashboard_tab5sorting
    </li><br>	
  <a name="dashboard_tab1sorting"></a>	
    <li>dashboard_tab1sorting<br>
		Enthält die Poistionierung jeder Gruppe im Tab 1. Der Wert wird mit der Schaltfläche "Set" geschrieben. Es wird nicht empfohlen dieses Attribut manuelle zu ändern
    </li><br>		
  <a name="dashboard_tab2sorting"></a>	
    <li>dashboard_tab2sorting<br>
		Enthält die Poistionierung jeder Gruppe im Tab 2. Der Wert wird mit der Schaltfläche "Set" geschrieben. Es wird nicht empfohlen dieses Attribut manuelle zu ändern
    </li><br>		
  <a name="dashboard_tab3sorting"></a>	
    <li>dashboard_tab3sorting<br>
		Enthält die Poistionierung jeder Gruppe im Tab 3. Der Wert wird mit der Schaltfläche "Set" geschrieben. Es wird nicht empfohlen dieses Attribut manuelle zu ändern
    </li><br>		
  <a name="dashboard_tab4sorting"></a>	
    <li>dashboard_tab4sorting<br>
		Enthält die Poistionierung jeder Gruppe im Tab 4. Der Wert wird mit der Schaltfläche "Set" geschrieben. Es wird nicht empfohlen dieses Attribut manuelle zu ändern
    </li><br>		
  <a name="dashboard_tab5sorting"></a>	
    <li>dashboard_tab5sorting<br>
		Enthält die Poistionierung jeder Gruppe im Tab 5. Der Wert wird mit der Schaltfläche "Set" geschrieben. Es wird nicht empfohlen dieses Attribut manuelle zu ändern
    </li><br>			
  <a name="dashboard_row"></a>	
    <li>dashboard_row<br>
   		Auswahl welche Zeilen angezeigt werden sollen. top (nur Oben), center (nur Mitte), bottom (nur Unten) und den Kombinationen daraus.<br>
		Standard: center
    </li><br>		
  <a name="dashboard_width"></a>	
    <li>dashboard_width<br>
        Zum bestimmen der Dashboardbreite. Der Wert kann in % (z.B. 80%) angegeben werden oder als absolute Breite (z.B. 1200) in Pixel.<br>
		Standard: 100%
    </li><br>		
  <a name="dashboard_colwidth"></a>	
    <li>dashboard_colwidth<br>
        Dieses Attribut ist nicht mehr zu verwenden und wird zu einem späteren Zeitpunkt entfernt. Es wurde ersetzt durch.<br>
		dashboard_rowcentercolwidth <br>
		Standard: 320
    </li><br>		
  <a name="dashboard_colheight"></a>	
    <li>dashboard_colheight<br>
        Dieses Attribut ist nicht mehr zu verwenden und wird zu einem späteren Zeitpunkt entfernt. Es wurde ersetzt durch <br>
		dashboard_rowcenterheight
    </li><br>		
  <a name="dashboard_rowcenterheight"></a>	
    <li>dashboard_rowcenterheight<br>
        Höhe der mittleren Zeile, in der die Gruppen angeordnet werden. <br>
		Standard: 400
    </li><br>			
  <a name="dashboard_rowcentercolwidth"></a>	
    <li>dashboard_rowcentercolwidth<br>
		Über dieses Attribut wird die Breite der einzelnen Spalten der mittleren Dashboardreihe festgelegt. Dabei kann je Spalte ein separater Wert hinterlegt werden. 
		Die Werte sind durch ein Komma (ohne Leerzeichen) zu trennen. Jeder Wert bestimmt die Spaltenbreite in %! Der erste Wert gibt die Breite der ersten Spalte an, 
		der zweite Wert die Breite der zweiten Spalte usw. Ist die Summe der Breite größer als 100 werden die Spaltenbreiten reduziert.
		Sind mehr Spalten als Breiten definiert werden die fehlenden Breiten um die Differenz zu 100 festgelegt. Sind hingegen weniger Spalten als Werte definiert werden 
		die überschüssigen Werte ignoriert.<br>
		Standard: 100
    </li><br>			
  <a name="dashboard_rowtopheight"></a>	
    <li>dashboard_rowtopheight<br>
        Höhe der oberen Zeile, in der die Gruppen angeordnet werden. <br>
		Standard: 250
    </li><br>		
  <a name="dashboard_rowbottomheight"></a>	
    <li>"dashboard_rowbottomheight<br>
        Höhe der unteren Zeile, in der die Gruppen angeordnet werden.<br>
		Standard: 250
    </li><br>		
  <a name="dashboard_groups"></a>	
    <li>dashboard_groups<br>
		Dieses Attribut ist nicht mehr zu verwenden und wird zu einem späteren Zeitpunkt entfernt. Es wurde ersetzt durch <br>
		dashboard_tab1groups, dashboard_tab2groups, dashboard_tab3groups, dashboard_tab4groups, dashboard_tab5groups.
    </li><br>		
  <a name="dashboard_tab1groups"></a>	
    <li>dashboard_tab1groups<br>
		Durch Komma getrennte Liste mit den Namen der Gruppen, die im Tab 1 angezeigt werden. Falsche Gruppennamen werden hervorgehoben.
    </li><br>		
  <a name="dashboard_tab2groups"></a>	
    <li>dashboard_tab2groups<br>
		Durch Komma getrennte Liste mit den Namen der Gruppen, die im Tab 2 angezeigt werden. Falsche Gruppennamen werden hervorgehoben.
    </li><br>		
  <a name="dashboard_tab3groups"></a>	
    <li>dashboard_tab3groups<br>
		Durch Komma getrennte Liste mit den Namen der Gruppen, die im Tab 3 angezeigt werden. Falsche Gruppennamen werden hervorgehoben.
    </li><br>	
  <a name="dashboard_tab4groups"></a>	
    <li>dashboard_tab4groups<br>
		Durch Komma getrennte Liste mit den Namen der Gruppen, die im Tab 4 angezeigt werden. Falsche Gruppennamen werden hervorgehoben.
    </li><br>	
  <a name="dashboard_tab5groups"></a>	
    <li>dashboard_tab5groups<br>
		Durch Komma getrennte Liste mit den Namen der Gruppen, die im Tab 5 angezeigt werden. Falsche Gruppennamen werden hervorgehoben.
    </li><br>	
  <a name="dashboard_tab1icon"></a>	
    <li>dashboard_tab1icon<br>
		Zeigt am Tab ein Icon an. Es muss sich dabei um ein exisitereindes Icon mit modpath Verzeichnis handeln. Handelt es sich um ein SVG Icon kann der Suffix @colorname für die Farbe des Icons angegeben werden.
    </li><br>
  <a name="dashboard_tab2icon"></a>	
    <li>dashboard_tab2icon<br>
		Zeigt am Tab ein Icon an. Es muss sich dabei um ein exisitereindes Icon mit modpath Verzeichnis handeln. Handelt es sich um ein SVG Icon kann der Suffix @colorname für die Farbe des Icons angegeben werden.
    </li><br>	
  <a name="dashboard_tab3icon"></a>	
    <li>dashboard_tab3icon<br>
		Zeigt am Tab ein Icon an. Es muss sich dabei um ein exisitereindes Icon mit modpath Verzeichnis handeln. Handelt es sich um ein SVG Icon kann der Suffix @colorname für die Farbe des Icons angegeben werden.
    </li><br>	
  <a name="dashboard_tab4icon"></a>	
    <li>dashboard_tab4icon<br>
		Zeigt am Tab ein Icon an. Es muss sich dabei um ein exisitereindes Icon mit modpath Verzeichnis handeln. Handelt es sich um ein SVG Icon kann der Suffix @colorname für die Farbe des Icons angegeben werden.
    </li><br>	
  <a name="dashboard_tab5icon"></a>	
    <li>dashboard_tab5icon<br>
		Zeigt am Tab ein Icon an. Es muss sich dabei um ein exisitereindes Icon mit modpath Verzeichnis handeln. Handelt es sich um ein SVG Icon kann der Suffix @colorname für die Farbe des Icons angegeben werden.
    </li><br>	
  <a name="dashboard_lockstate"></a>		
    <li>dashboard_lockstate<br>
		Bei Dashboard Einstellung "unlock" kann dieses bearbeitet werden. Bei der Einstellung "lock" können keine Änderung vorgenommen werden. <br>
		Wenn die Leiste ausgeblendet ist (dashboard_showtabs) ist das Dashboard gespert. Die Bearbeitung ist daher nur mit sichtbarer Buttonbar möglich ist.<br>
		Standard: unlock
    </li><br>	
  <a name="dashboard_colcount"></a>	
    <li>dashboard_colcount<br>
		Die Anzahl der Spalten in der  Gruppen dargestellt werden können. Dennoch ist es möglich, mehrere Gruppen <br>
		in einer Spalte nebeneinander zu positionieren. Dies ist abhängig von der Breite der Spalten und Gruppen. <br>
		Gilt nur für die mittlere Spalte! <br>
		Standard: 1
    </li><br>		
 <a name="dashboard_showfullsize"></a>	
    <li>dashboard_showfullsize<br>
		Blendet die FHEMWEB Raumliste (kompleter linker Bereich der Seite) und den oberen Bereich von FHEMWEB aus wenn der Wert auf 1 gesetzt ist.<br>
		Default: 0
    </li><br>		
 <a name="dashboard_showtabs"></a>	
    <li>dashboard_showtabs<br>
		Zeigt die Tabs des Dashboards oben oder unten an, oder blendet diese aus. Dies gilt auch für die Schalterleiste. Wenn die Schalterleiste ausgeblendet wird ist das Dashboard gespert.<br>
		Standard: tabs-and-buttonbar-at-the-top
    </li><br>	
 <a name="dashboard_showhelper"></a>		
    <li>dashboard_showhelper<br>
		Blendet Ränder ein, die eine Positionierung der Gruppen erleichtern. <br>
		Standard: 1
    </li><br>	 
 <a name="dashboard_showtooglebuttons"></a>		
    <li>dashboard_showtooglebuttons<br>
		Zeigt eine Schaltfläche in jeder Gruppe mit der man diese auf- und zuklappen kann.<br>
		Standard: 1
    </li><br>	
 <a name="dashboard_debug"></a>		
    <li>dashboard_debug<br>
        Zeigt Debug-Felder an. Sollte nicht gesetzt werden!<br>
		Standard: 0
    </li><br>	

</ul>

=end html_DE
=cut

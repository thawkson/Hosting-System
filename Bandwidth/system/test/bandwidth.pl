#!/usr/bin/perl

use Sort::Fields;

#################################################################
#                       Bandwidth Useage Script                 #
#                                                               #
# This script is pretty much the heart and soul of l33t.ca as a #
# financial entity on the internet. This script will monitor all#
# our hosted sites total used bandwidth and calculate and track #
# how much money they owe us and how much money they've paid us #
# for their use. May God have mercy on our damned souls.        #
#################################################################


require("L33Tmanager_vars.pl");
require("L33Tmanager_lib.pl");

$MONTH = `date +%b`;
chomp($MONTH);
$FULLMONTH = `date +%B`;
chomp($FULLMONTH);
$YEAR = `date +%Y`;
chomp($YEAR);
$bandwidthDate = "$MONTH$YEAR";

if(-e "/root/bandwidth.run")
{
	exit();
}

open(TMP, ">/root/bandwidth.run");
close(TMP);

open(BW, $BANDWIDTHLASTRUN);
$line = <BW>;
close BW;
($lastrun_month, $lastrun_year) = $line =~ /(\w+) (\d+)/;

if ($lastrun_month ne $MONTH || $lastrun_year ne $YEAR) {
	unlink($BANDWIDTHSAVE);
	open(BW, "+> $BANDWIDTHLASTRUN");
	print BW "$MONTH $YEAR";
	close BW;
}



opendir(LOGDIR,$HTTP_LOGDIR);
@files = grep(/access_log/, readdir(LOGDIR));
closedir(LOGDIR);

opendir(FTPLOGS,$FTP_LOGDIR);
@ftpFiles = grep(/xferlog/, readdir(FTPLOGS));
closedir(FTPLOGS);

opendir(PACKLOGS,$PACKET_LOGDIR);
@packetFiles = grep(/packetlog/, readdir(PACKLOGS));
closedir(PACKLOGS);

opendir(DEVLOGS,$DEV_LOGDIR);
@devFiles = grep(/devlog/, readdir(DEVLOGS));
closedir(DEVLOGS);

$header_html = qq~<!--#include virtual="$LARGEHEADER_URL"-->~;
$footer_html = qq~<!--#include virtual="$LARGEFOOTER_URL"-->~;

$lowDate = -1; #Make both of these slightly out of range so that the if statements work
$highDate = 0;

$lastLine = "nothing";

$ftpLowDate = -1;
$ftpHighDate = 0;
$packetHighDate = 0;
$devHighDate = 0;

$ftpLastLine = "nothing";
$packetLastLine = "nothing";
$devLastLine = "nothing";

$starttime = `date +%s`;
chomp $starttime;

#NOOOOO!!
$monthLookup{Jan} = 1;
$monthLookup{Feb} = 2;
$monthLookup{Mar} = 3;
$monthLookup{Apr} = 4;
$monthLookup{May} = 5;
$monthLookup{Jun} = 6;
$monthLookup{Jul} = 7;
$monthLookup{Aug} = 8;
$monthLookup{Sep} = 9;
$monthLookup{Oct} = 10;
$monthLookup{Nov} = 11;
$monthLookup{Dec} = 12;
$fullMonthLookup{Jan} = "January";
$fullMonthLookup{Feb} = "February";
$fullMonthLookup{Mar} = "March";
$fullMonthLookup{Apr} = "April";
$fullMonthLookup{May} = "May";
$fullMonthLookup{Jun} = "June";
$fullMonthLookup{Jul} = "July";
$fullMonthLookup{Aug} = "August";
$fullMonthLookup{Sep} = "September";
$fullMonthLookup{Oct} = "October";
$fullMonthLookup{Nov} = "November";
$fullMonthLookup{Dec} = "December";
$ltMonthLookup{0} = "Jan";
$ltMonthLookup{1} = "Feb";
$ltMonthLookup{2} = "Mar";
$ltMonthLookup{3} = "Apr";
$ltMonthLookup{4} = "May";
$ltMonthLookup{5} = "Jun";
$ltMonthLookup{6} = "Jul";
$ltMonthLookup{7} = "Aug";
$ltMonthLookup{8} = "Sep";
$ltMonthLookup{9} = "Oct";
$ltMonthLookup{10} = "Nov";
$ltMonthLookup{11} = "Dec";

system("echo \"Reading domain lookup table...\"");

opendir(USERDIR,$PROFILESDIR);
@users = grep(!/^\.\.?/, readdir(USERDIR));
closedir(USERDIR);

system("echo \"Building domain lookup table...\"");
foreach $user (@users) {
	undef @domains;
	next if ($user =~ /_/);
	push @newusers, $user;
       need("$PROFILESDIR$user");
       foreach $domain (@domains) {
               if ($domain ne "") {
                       $lookup{$domain} = $user;
               }
       }
}

@users = @newusers;

$startTime = time;
######################
#Load the saved state#
######################
if( -e $BANDWIDTHSAVE)
{
	print "Found save file, loading now...\n";
	open SAVEFILE, $BANDWIDTHSAVE;
	
	$lastLine = <SAVEFILE>;
	chomp($lastLine);

	$highDate = <SAVEFILE>;
	chomp($highDate);

	$realHighDate = <SAVEFILE>;
	chomp($realHighDate);

	$lowDate = <SAVEFILE>;
	chomp($lowDate);

	$realLowDate = <SAVEFILE>;
	chomp($realLowDate);

	$ftpLastLine = <SAVEFILE>;
	chomp($ftpLastLine);

	$ftpHighDate = <SAVEFILE>;
	chomp($ftpHighDate);

	$ftpLowDate = <SAVEFILE>;
	chomp($ftpLowDate);

	$packetLastLine = <SAVEFILE>;
	chomp($packetLastLine);
	
	$packetHighDate = <SAVEFILE>;
	chomp($packetHighDate);

	$devLastLine = <SAVEFILE>;
	chomp($devLastLine);

	$devHighDate = <SAVEFILE>;
	chomp($devHighDate);
	
	$totallines = <SAVEFILE>;
	chomp($totallines);

	$devRecv = <SAVEFILE>;
	chomp($devRecv);

	$devSend = <SAVEFILE>;
	chomp($devSend);
	
	$tmp = "";
	
	$i = 0;
	while($tmp ne ";;")
	{
		$tmp = <SAVEFILE>;
                chomp($tmp);
                $i++;
		@lineDat = split(/\s/, $tmp);
		next if ($lineDat[0] =~ /[^a-z0-9\-\_\.]/ || $lineDat[1] =~ /[^a-z0-9\-\_\.]/);
		$sites{$lineDat[0]}{'bandwidth'} = $lineDat[2];
		$sites{$lineDat[0]}{'subdomains'}{$lineDat[1]}{'bandwidth'} = $lineDat[3];
	}

	while($tmp ne ";;")
	{
		$tmp = <SAVEFILE>;
		chomp($tmp);		
		$i++;
		@lineDat = split(/\s/, $tmp);
		next if ($lineDat[0] =~ /[^a-z0-9\-\_\.]/ || $lineDat[1] =~ /[^a-z0-9\-\_\.]/);
		$sites{$lineDat[0]}{'subdomains'}{$lineDat[1]}{'files'}{$lineDat[2]}{'hits'} = $lineDat[3];
		$sites{$lineDat[0]}{'subdomains'}{$lineDat[1]}{'files'}{$lineDat[2]}{'bandwidth'} = $lineDat[4];

	}
	while(!eof(SAVEFILE))
	{
		$tmp = <SAVEFILE>;
		chomp($tmp);
		$i++;
		@lineDat = split(/\s/, $tmp);
		next if ($lineDat[0] =~ /[^a-z0-9\-\_\.]/ || $lineDat[1] =~ /[^a-z0-9\-\_\.]/);
		$sites{$lineDat[0]}{'subdomains'}{$lineDat[1]}{'ports'}{$lineDat[2]}{'bandwidth'} = $lineDat[3];
	}
	print "$i lines of code loaded...\n";
	

$parseTime += (time - $startTime);
printf "Finished including save file, took %d minutes %d seconds\n", int(($parseTime)/60), ($parseTime) % 60;
}



#CHEAP CHEAP HACK!!
$lowDate = -1 if $lowDate eq "";



#######################################################################
#Make sure that we feed the log files in a chronologically ordered way#
#######################################################################
foreach $logfile (@files)
{
	open( LOGFILE, $HTTP_LOGDIR . $logfile);
	
	$tmp = <LOGFILE>;
	
	if( $tmp ne "")
	{

		@temp = split(/\s+/,$tmp);
        	$fileName = $temp[7];
		$tmp =~ s/"[^"]*"//g;
        	@lineDat = split(/\s+/,$tmp);
	        $date = $lineDat[4];
		($day, $month, $year, $hour, $min, $sec) = ($date =~ /(\d+)\/([A-Za-z]+)\/(\d+):(\d+):(\d+):(\d+)/);
	
		$tmp = $year * 32140800 + $monthLookup{$month} * 2678400 + ($day - 1) * 86400 + $hour * 3600 + $min * 60 + $sec;

		$fileSort{$logfile} = $tmp; 
	}
	
	close(LOGFILE);
}	
	

@files = keys(%fileSort);
@size = values(%fileSort);

$movement = 1;
while($movement)
{
        $movement = 0;

        for($i = 0; $i < (@size - 1); $i++)
        {
		if($size[$i+1] < $size[$i])
                {
                        $movement = 1;
                        $tmp = $size[$i+1];
                        $size[$i+1] = $size[$i];
                        $size[$i] = $tmp;

                        $tmp = $files[$i+1];
                        $files[$i+1] = $files[$i];
                        $files[$i] = $tmp;
                }
        }
}
##########
#FTPSTUFF#
#######################################################################
#Make sure that we feed the log files in a chronologically ordered way#
#######################################################################
foreach $logfile (@ftpFiles)
{
	open( LOGFILE, $FTP_LOGDIR . $logfile);
	
	$tmp = <LOGFILE>;
	
	if( $tmp ne "")
	{

		@temp = split(/\s+/,$tmp);
        	
		$month = @temp[1];
		$day = @temp[2];
		$year = @temp[4];
		
		$date = @temp[3];
		$hour, $min, $sec = ($date =~ /(\d+):(\d+):(\d+)/);
	
		$tmp = $year * 32140800 + $monthLookup{$month} * 2678400 + ($day - 1) * 86400 + $hour * 3600 + $min * 60 + $sec;

		$ftpFileSort{$logfile} = $tmp; 
	}
	
	close(LOGFILE);
}	
	

@ftpFiles = keys(%ftpFileSort);
@ftpSize = values(%ftpFileSort);

$movement = 1;
while($movement)
{
        $movement = 0;

        for($i = 0; $i < (@ftpSize - 1); $i++)
        {
		if($ftpSize[$i+1] < $ftpSize[$i])
                {
                        $movement = 1;
                        $tmp = $ftpSize[$i+1];
                        $ftpSize[$i+1] = $ftpSize[$i];
                        $ftpSize[$i] = $tmp;

                        $tmp = $ftpFiles[$i+1];
                        $ftpFiles[$i+1] = $ftpFiles[$i];
                        $ftpFiles[$i] = $tmp;
                }
        }
}


##########
#PACKETSTUFF#
#######################################################################
#Make sure that we feed the log files in a chronologically ordered way#
#######################################################################
foreach $logfile (@packetFiles)
{
	open( LOGFILE, $PACKET_LOGDIR . $logfile);
	
	$tmp = <LOGFILE>;
	
	if( $tmp ne "")
	{

		@temp = split(/\s+/,$tmp);
        	
		$tmp = $temp[0];

		$packetFileSort{$logfile} = $tmp; 
	}
	
	close(LOGFILE);
}	
	

@packetFiles = keys(%packetFileSort);
@packetSize = values(%packetFileSort);

$movement = 1;
while($movement)
{
        $movement = 0;

        for($i = 0; $i < (@packetSize - 1); $i++)
        {
		if($packetSize[$i+1] < $packetSize[$i])
                {
                        $movement = 1;
                        $tmp = $packetSize[$i+1];
                        $packetSize[$i+1] = $packetSize[$i];
                        $packetSize[$i] = $tmp;

                        $tmp = $packetFiles[$i+1];
                        $packetFiles[$i+1] = $packetFiles[$i];
                        $packetFiles[$i] = $tmp;
                }
        }
}


##########
#DEVSTUFF#
#######################################################################
#Make sure that we feed the log files in a chronologically ordered way#
#######################################################################
foreach $logfile (@devFiles)
{
	open( LOGFILE, $DEV_LOGDIR . $logfile);
	
	$tmp = <LOGFILE>;
	
	if( $tmp ne "")
	{

		@temp = split(/\s+/,$tmp);
        	
		$tmp = $temp[0];

		$devFileSort{$logfile} = $tmp; 
	}
	
	close(LOGFILE);
}	
	

@devFiles = keys(%devFileSort);
@devSize = values(%devFileSort);

$movement = 1;
while($movement)
{
        $movement = 0;

        for($i = 0; $i < (@devSize - 1); $i++)
        {
		if($devSize[$i+1] < $devSize[$i])
                {
                        $movement = 1;
                        $tmp = $devSize[$i+1];
                        $devSize[$i+1] = $devSize[$i];
                        $devSize[$i] = $tmp;

                        $tmp = $devFiles[$i+1];
                        $devFiles[$i+1] = $devFiles[$i];
                        $devFiles[$i] = $tmp;
                }
        }
}

print "Beginning to parse HTTPD log files...\n";

$run = 0;

@files = split(/\n/,`ls -1 -v -r $HTTP_LOGDIR | grep access_log`);

foreach $logfile (@files) {

	open( LOGFILE, $HTTP_LOGDIR . $logfile) || die "Can't open Log File";
	
	###################################################
	#Check to see if we even need to analyze this file#
	#Note : Worst. Code. Ever			  #
	###################################################
	
	seek(LOGFILE, (-s LOGFILE) -2000 , 0);

	while(!eof(LOGFILE))
	{ $tmp = <LOGFILE>;}
	
	if( $tmp ne "")
	{
	
	
		@temp = split(/\s+/,$tmp);
        	$fileName = $temp[7];
		$tmp =~ s/"[^"]*"//g;
        	@lineDat = split(/\s+/,$tmp);
	        $date = $lineDat[4];
		($day, $month, $year, $hour, $min, $sec) = ($date =~ /(\d+)\/([A-Za-z]+)\/(\d+):(\d+):(\d+):(\d+)/);
	
		$tmp = $year * 32140800 + $monthLookup{$month} * 2678400 + ($day - 1) * 86400 + $hour * 3600 + $min * 60 + $sec; 
		
		if( ($tmp < $highDate) || ($month ne $MONTH))
		{	
			print "Skipping httpd log file $logfile\n";
			next;
		}
		else
		{
			print "Parsing httpd log file $logfile\n";
		}
		
	
	}
	else
	{
		next;
	}

	seek(LOGFILE, 0, 0);

	$i = 0;

	$startTime = time;
	

	
	while(!eof(LOGFILE))
	{
		$testline = <LOGFILE>;
		chomp($testline);
				
		#Yet another cheap hack
		if(($testline eq $lastLine)||($lastLine eq "nothing"))
		{
			$run = 1;
		}
			
		
		
		if($run == 1)
		{

		$lastLine = $testline;
		@temp = split(/\s+/,$testline);
		$fileName = @temp[7];
		$testline =~ s/"[^"]*"//g;
		@lineDat = split(/\s+/,$testline);
		$date = $lineDat[4];
		($day, $month, $year, $hour, $min, $sec) = ($date =~ /(\d+)\/([A-Za-z]+)\/(\d+):(\d+):(\d+):(\d+)/);
		
		$tmp = $year * 32140800 + $monthLookup{$month} * 2678400 + ($day - 1) * 86400 + $hour * 3600 + $min * 60 + $sec; 

		$fileName =~ s/\?.*//g;

		if( ($tmp eq "") || ($tmp <= 0))
		{
			next;
		}

	
		$lineDat[0] = lc $lineDat[0];
		if(($lineDat[7] ne "-")&&($month eq $MONTH))
		{
			#UPDATE THEIR TOTAL BANDWIDTH USEAGE
			$sites{$lineDat[0]}{'bandwidth'} += $lineDat[7];
			$sites{$lineDat[0]}{'subdomains'}{$lineDat[0]}{'bandwidth'} += $lineDat[7];

			#UPDATE THEIR FILE HIT TALLY
			$sites{$lineDat[0]}{'subdomains'}{$lineDat[0]}{'files'}{$fileName}{'hits'} += 1;
		
			#UPDATE THEIR FILE BANDWIDTH TALLY
			$sites{$lineDat[0]}{'subdomains'}{$lineDat[0]}{'files'}{$fileName}{'bandwidth'} += $lineDat[7];

			#UPDATE OUR DATE SPAN
			$tmp = $year * 32140800 + $monthLookup{$month} * 2678400 + ($day - 1) * 86400 + $hour * 3600 + $min * 60 + $sec;  
			$totallines++;
		}
		if( $month eq $MONTH)
		{
			if ($tmp > $highDate) {
					$highDate = $tmp;
					$realHighDate = "$month $day, $year - $hour:$min";
			}
			if ($tmp < $lowDate || $lowDate == -1) {
					$lowDate = $tmp;
					$realLowDate = "$month $day, $year - $hour:$min";
			}
		}
		}
			
	$i++;
	}
	close(LOGFILE);
	
	$stopTime = time;
	
	$parseTime += ($stopTime - $startTime);
	
	printf "Finished parsing $logfile, took %d minutes %d seconds\n", int(($stopTime - $startTime)/60), ($stopTime - $startTime) % 60;
}

printf "Finished parsing HTTPD log files, took %d minutes %d seconds\n", int(($parseTime)/60), ($parseTime) % 60;


#####################################################################
#GROUPING
#####################################################################
###Group main L33T.ca sites

$startTime = time;

print "Beginning to group users... ";

$buffer = "";
open L33TDOM, "/root/l33t_domains";
foreach (<L33TDOM>) {
        $buffer .= $_;
}
close L33TDOM;
@l33tdomains = split /\n/, $buffer;

##Group all l33t main domains
foreach $domain (@l33tdomains) {
        if (scalar (keys %{$sites{$domain}})) {
                $sites{'l33t.ca'}{'subdomains'}{$domain}{'bandwidth'} +=  $sites{$domain}{'subdomains'}{$domain}{'bandwidth'};
                foreach $file (keys %{$sites{$domain}{'subdomains'}{$domain}{'files'}}) {
                        $sites{'l33t.ca'}{'subdomains'}{$domain}{'files'}{$file}{'hits'} += $sites{$domain}{'subdomains'}{$domain}{'files'}{$file}{'hits'};
                        $sites{'l33t.ca'}{'subdomains'}{$domain}{'files'}{$file}{'bandwidth'} += $sites{$domain}{'subdomains'}{$domain}{'files'}{$file}{'bandwidth'};
                }
                $sites{'l33t.ca'}{'bandwidth'} += $sites{$domain}{'bandwidth'};
                delete $sites{$domain};
        } else {
                delete $sites{$domain};
        }
}

####Group all domains into their users
foreach $site (keys %sites) {
	if ($site =~ /\./ && $site ne "l33t.ca") {
		if ($lookup{$site} ne "") {
			$sites{$lookup{$site}}{'subdomains'}{$site}{'bandwidth'} +=  $sites{$site}{'subdomains'}{$site}{'bandwidth'};
			foreach $file (keys %{$sites{$site}{'subdomains'}{$site}{'files'}}) {
				$sites{$lookup{$site}}{'subdomains'}{$site}{'files'}{$file}{'hits'} += $sites{$site}{'subdomains'}{$site}{'files'}{$file}{'hits'};
				$sites{$lookup{$site}}{'subdomains'}{$site}{'files'}{$file}{'bandwidth'} += $sites{$site}{'subdomains'}{$site}{'files'}{$file}{'bandwidth'};
			}
                	$sites{$lookup{$site}}{'bandwidth'} += $sites{$site}{'bandwidth'};
                	delete $sites{$site};
		} else {
			delete $sites{$site};
		}
        }

	#Weird bug, little fix..
	if ($site =~ /\//) {
		delete $sites{$site};
	}
}

$stopTime = time;
printf "done! took %d minutes %d seconds\n", int(($stopTime - $startTime)/60), ($stopTime - $startTime) % 60;

print "Doing initial sorting...";
$startTime = time;

#############
#	    #
#FTP STUFF!!#
#           #
#############

print "Beginning to parse FTP log files...\n";

$run = 0;

foreach $logfile (@ftpFiles) {

	open( LOGFILE, $FTP_LOGDIR . $logfile) || die "Can't open Log File";
	
	###################################################
	#Check to see if we even need to analyze this file#
	#Note : Worst. Code. Ever			  #
	###################################################
	
	seek(LOGFILE, (-s LOGFILE) -2000 , 0);

	while(!eof(LOGFILE))
	{ $tmp = <LOGFILE>;}
	
	if( $tmp ne "")
	{
	
	
		@temp = split(/\s+/,$tmp);
        	
		$month = @temp[1];
		$day = @temp[2];
		$year = @temp[4];
		
		$date = @temp[3];
		($hour, $min, $sec) = ($date =~ /(\d+):(\d+):(\d+)/);
	
		$tmp = $year * 32140800 + $monthLookup{$month} * 2678400 + ($day - 1) * 86400 + $hour * 3600 + $min * 60 + $sec;

		
		if( ($tmp <= $ftpHighDate) || ($month ne $MONTH))
		{	
			print "Skipping ftp log file $logfile\n";
			next;
		}
		else
		{
			print "Parsing ftp log file $logfile\n";
		}
		
	
	}
	else
	{
		next;
	}

	seek(LOGFILE, 0, 0);

	$i = 0;

	$startTime = time;
	
	while(!eof(LOGFILE))
	{
		$testline = <LOGFILE>;
		chomp($testline);
				
		#Yet another cheap hack
		if(($testline eq $ftpLastLine)||($ftpLastLine eq "nothing"))
		{
			$run = 1;
		}
			
		if($run == 1)
		{
		
		$ftpLastLine = $testline;
		
		@temp = split(/\s+/,$testline);
        	
		$month = $temp[1];
		$day = $temp[2];
		$year = $temp[4];
		
		$date = $temp[3];
		($hour, $min, $sec) = ($date =~ /(\d+):(\d+):(\d+)/);
	
		$tmp = $year * 32140800 + $monthLookup{$month} * 2678400 + ($day - 1) * 86400 + $hour * 3600 + $min * 60 + $sec;
		
		if( ($tmp eq "") || ($tmp <= 0))
		{
			#next;
		}
		
		$_ = $temp[13];
		if(!/@/)
		{
			if ($temp[13] =~ /(.*)_.*/) {
				$temp[13] = $1;
			}
		}
		else
		{
			$temp[13] = "l33t.ca";
		}
		
		$temp[13] = lc $temp[13];
		if(($month eq $MONTH))
		{
			#UPDATE THEIR TOTAL BANDWIDTH USEAGE

			#disabled - packet logger takes care of this bandwidth
			#$sites{$temp[13]}{'bandwidth'} += $temp[7];
			#$sites{$temp[13]}{'subdomains'}{'ftp'}{'bandwidth'} += $temp[7];
			
			#UPDATE OUR DATE SPAN
			$tmp = $year * 32140800 + $monthLookup{$month} * 2678400 + ($day - 1) * 86400 + $hour * 3600 + $min * 60 + $sec;  
			$totallines++;
		}
		if( $month eq $MONTH)
		{
			if ($tmp > $ftpHighDate) {
					$ftpHighDate = $tmp;
			}
			if ($tmp < $ftpLowDate || $ftpLowDate == -1) {
					$ftpLowDate = $tmp;
			}
		}
		}
			
	$i++;
	}
	close(LOGFILE);
	
	$stopTime = time;
	
	$parseTime += ($stopTime - $startTime);
	
	printf "Finished parsing $logfile, took %d minutes %d seconds\n", int(($stopTime - $startTime)/60), ($stopTime - $startTime) % 60;
}

printf "Finished parsing FTP log files, took %d minutes %d seconds\n", int(($parseTime)/60), ($parseTime) % 60;



#############
#	    #
#PACKET STUFF!!#
#           #
#############

print "Beginning to parse packet log files...\n";

$run = 0;

foreach $logfile (@packetFiles) {

	open( LOGFILE, $PACKET_LOGDIR . $logfile) || die "Can't open Log File";
	
	###################################################
	#Check to see if we even need to analyze this file#
	#Note : Worst. Code. Ever			  #
	###################################################
	
	seek(LOGFILE, (-s LOGFILE) -100 , 0);

	while(!eof(LOGFILE))
	{ $tmp = <LOGFILE>;}
	
	if( $tmp ne "")
	{
	
		@temp = split(/\s+/,$tmp);
        	
		$tmp = $temp[0];
		$mon = (localtime($temp[0]))[4];
			
		if($tmp <= $packetHighDate||($MONTH ne $ltMonthLookup{$mon}))
		{	
			print "Skipping packet log file $logfile\n";
			next;
		}
		else
		{
			print "Parsing packet log file $logfile\n";
		}
		
	
	}
	else
	{
		next;
	}

	seek(LOGFILE, 0, 0);

	$i = 0;

	$startTime = time;
	
	while(!eof(LOGFILE))
	{
		$testline = <LOGFILE>;
		chomp($testline);
				
		#Yet another cheap hack
		if(($testline eq $packetLastLine)||($packetLastLine eq "nothing"))
		{
			$run = 1;
		}
			
		if($run == 1)
		{
		
		$packetLastLine = $testline;
		
		@temp = split(/\s+/,$testline);
        	
		$tmp = $temp[0];
		$mon = (localtime($temp[0]))[4];
		if ($MONTH eq $ltMonthLookup{$mon}) {
			$user = (getpwuid($temp[1]))[0];
			if ($user =~ /(.*)_.*/) {
				$user = $1;
			}
			#UPDATE THEIR TOTAL BANDWIDTH USEAGE
			$sites{$user}{'bandwidth'} += $temp[4];
			$sites{$user}{'subdomains'}{'other'}{'bandwidth'} += $temp[4];
			$sites{$user}{'subdomains'}{'other'}{'ports'}{$temp[3]}{'bandwidth'} += $temp[4];
			if ($tmp > $packetHighDate) {
				$packetHighDate = $tmp;
			}
			$totallines++;
		}
		}
	}
	close(LOGFILE);
	
	$stopTime = time;
	
	$parseTime += ($stopTime - $startTime);
	
	printf "Finished parsing $logfile, took %d minutes %d seconds\n", int(($stopTime - $startTime)/60), ($stopTime - $startTime) % 60;
}


#############
#	    #
#DEV STUFF!!#
#           #
#############

print "Beginning to parse device log files...\n";

$run = 0;

foreach $logfile (@devFiles) {

	open( LOGFILE, $DEV_LOGDIR . $logfile) || die "Can't open Log File";
	
	###################################################
	#Check to see if we even need to analyze this file#
	#Note : Worst. Code. Ever			  #
	###################################################
	
	seek(LOGFILE, (-s LOGFILE) -100 , 0);

	while(!eof(LOGFILE))
	{ $tmp = <LOGFILE>;}
	
	if( $tmp ne "")
	{
	
		@temp = split(/\s+/,$tmp);
        	
		$tmp = $temp[0];
		$mon = (localtime($temp[0]))[4];	
		if($tmp <= $devHighDate || $MONTH ne $ltMonthLookup{$mon})
		{	
			print "Skipping device log file $logfile\n";
			next;
		}
		else
		{
			print "Parsing device log file $logfile\n";
		}
		
	
	}
	else
	{
		next;
	}

	seek(LOGFILE, 0, 0);

	$i = 0;

	$startTime = time;
	
	while(!eof(LOGFILE))
	{
		$testline = <LOGFILE>;
		chomp($testline);
				
		#Yet another cheap hack
		if(($testline eq $devLastLine)||($devLastLine eq "nothing"))
		{
			$run = 1;
		}
			
		if($run == 1)
		{
		
		$devLastLine = $testline;
		
		@temp = split(/\s+/,$testline);
        	
		$tmp = $temp[0];
		$mon = (localtime($temp[0]))[4];
		if ($MONTH eq $ltMonthLookup{$mon}) {
			if ($temp[2] eq "eth0") {
				$devRecv += $temp[5];
				$devSend += $temp[6];
			}
			if ($tmp > $devHighDate) {
				$devHighDate = $tmp;
			}
			$totallines++;
		}
		}
	}
	close(LOGFILE);
	
	$stopTime = time;
	
	$parseTime += ($stopTime - $startTime);
	
	printf "Finished parsing $logfile, took %d minutes %d seconds\n", int(($stopTime - $startTime)/60), ($stopTime - $startTime) % 60;
}

printf "Finished parsing Device log files, took %d minutes %d seconds\n", int(($parseTime)/60), ($parseTime) % 60;

################################
#Save the state of the program #
################################

print "Saving current state...";

$startTime = time;

open(OUT, "> $BANDWIDTHSAVE") or die "Can't open save file";

print OUT qq~$lastLine\n~;

print OUT qq~$highDate\n~;

print OUT qq~$realHighDate\n~;

print OUT qq~$lowDate\n~;

print OUT qq~$realLowDate\n~;

print OUT qq~$ftpLastLine\n~;

print OUT qq~$ftpHighDate\n~;

print OUT qq~$ftpLowDate\n~;

print OUT qq~$packetLastLine\n~;

print OUT qq~$packetHighDate\n~;

print OUT qq~$devLastLine\n~;

print OUT qq~$devHighDate\n~;

print OUT qq~$totallines\n~;

print OUT qq~$devRecv\n~;
print OUT qq~$devSend\n~;

foreach $key1 (keys %sites)
{
	foreach $key2 (keys %{$sites{$key1}{'subdomains'}})
	{
		print OUT qq~$key1 $key2 $sites{$key1}{'bandwidth'} $sites{$key1}{'subdomains'}{$key2}{'bandwidth'}\n~;
	}
}

print OUT ";;\n";

foreach $key1 (keys %sites)
{
	foreach $key2 (keys %{$sites{$key1}{'subdomains'}})
	{
		foreach $key3 (keys %{$sites{$key1}{'subdomains'}{$key2}{'files'}})	
		{
			print OUT qq~$key1 $key2 $key3 $sites{$key1}{'subdomains'}{$key2}{'files'}{$key3}{'hits'} $sites{$key1}{'subdomains'}{$key2}{'files'}{$key3}{'bandwidth'}\n~;
		}
	}
}

print OUT ";;\n";

foreach $key1 (keys %sites)
{
	foreach $key2 (keys %{$sites{$key1}{'subdomains'}})
	{
		foreach $key3 (keys %{$sites{$key1}{'subdomains'}{$key2}{'ports'}})
		{
			print OUT qq~$key1 $key2 $key3 $sites{$key1}{'subdomains'}{$key2}{'ports'}{$key3}{'bandwidth'}\n~;
		}
	}
}

close OUT;

$stopTime = time;

$parseTime += ($stopTime - $startTime);
	
printf "done! took %d minutes %d seconds\n", int(($stopTime - $startTime)/60), ($stopTime - $startTime) % 60;

$stopTime = time;

#######################
#Remove non-existant users for display only
#######################
foreach $user (keys %sites) {
	next if (-e "$PROFILESDIR$user" || $user eq "l33t.ca");
	delete $sites{$user};
}
#######################
#Sort for bandwidth#
#######################
@bandwidth = keys %sites;
$c = 0;
@sortString = "";
foreach $thingy (@bandwidth)
{
	$sortString[$c] = "$sites{$thingy}{'bandwidth'} $thingy";
	$c++;			
}

$sortRoutine_1n = make_fieldsort ['-1n'], @sortString;

@sorted = $sortRoutine_1n->(@sortString);

$c = 0;
foreach $thingy (@sorted)
{
	@rcv = split(/ /, $thingy);
	
	$bandwidth[$c] = $rcv[1];
	$c++;
}

#######################
#Sort by name#
#######################
@name = keys %sites;

$c = 0;
@sortString = "";
foreach $thingy (@name)
{
	$sortString[$c] = "$thingy";
	$c++;			
}

$sortRoutine_1 = make_fieldsort ['1'], @sortString;

@sorted = $sortRoutine_1->(@sortString);

$c = 0;
foreach $thingy (@sorted)
{
	$name[$c] = $thingy;
	$c++;
}

$stopTime = time;

$parseTime += ($stopTime - $startTime);

print "Starting user and sub-user bandwidth calculations and sorting...";
$startTime = time;
##############################################################
#We gotta project what their monthly bandwidth useage will be#
##############################################################

$deltaDate = $highDate - $lowDate;
$highDay = &getHighDay($MONTH);
$highDaySec = ($highDay * 86400) + ($monthLookup{$MONTH} * 2678400) + ($YEAR * 32140800);
$highDayDelta = $highDaySec - $lowDate;
$average = $highDayDelta / $deltaDate;

######CALCULATE USER INFORMATION######

$totalBytes = $devRecv + $devSend;
$totalProjectedBytes = $totalBytes * $average;
$rankCount=1;
foreach $key (@bandwidth)
{
	$bytes = $sites{$key}{'bandwidth'};
	$sites{$key}{'rank'} = $rankCount;
	$projection = $bytes * $average;	
	$sites{$key}{'projectedbandwidth'} = $projection;
	$rankCount++;

	###SORT SUBDOMAINS BANDWIDTH TO GET RANK###
	@subdomains = keys %{$sites{$key}{'subdomains'}};
	$c = 0;
	@sortString="";
	foreach $thingy (@subdomains)
	{
		$sortString[$c] = 
"$sites{$key}{'subdomains'}{$thingy}{'bandwidth'} $thingy";		
		$c++;
	}

	#@sorted = fieldsort ['-1n'], @sortString;
	@sorted = $sortRoutine_1n->(@sortString);

	$c = 0;
	foreach $thingy (@sorted)
	{
		@rcv = split(/ /, $thingy);
	
		$subdomains[$c] = $rcv[1];
		$c++;
	}
	
	######CALCULATE SUBDOMAIN INFOMRATION######
	$k = 1;
	$j = 0;
	foreach $subdomain (@subdomains) {
		$j++;
		$bytes = $sites{$key}{'subdomains'}{$subdomain}{'bandwidth'};
		$sites{$key}{'subdomains'}{$subdomain}{'rank'} = $k;
		$projection = $bytes * $average;	
		$sites{$key}{'subdomains'}{$subdomain}{'projectedbandwidth'} = $projection;
		$k++;

		###SORT FILES BY BANDWIDTH TO GET RANK###
		@files = keys %{$sites{$key}{'subdomains'}{$subdomain}{'files'}};
		
		
		$c = 0;
		#for($x = 0; $x < @sortedString; $x++)
		#{$sortedString[$x] = "";}
		@sortString = "";
		foreach $thingy (@files)
		{
			$sortString[$c] = "$sites{$key}{'subdomains'}{$subdomain}{'files'}{$thingy}{'bandwidth'} $thingy";
			$c++;			
		}
	
		#@sorted = fieldsort ['-1n'], @sortString;
		@sorted = $sortRoutine_1n->(@sortString);
		
		$c = 0;
		foreach $thingy (@sorted)
		{
			@rcv = split(/\s/, $thingy);
			
			$files[$c] = $rcv[1];
			$c++;
		}	
		

		######CALCULATE FILE INFORMATION FOR EACH SUBDOMAIN######
		$l = 1;
		foreach $file (@files) {
			$bytes = $sites{$key}{'subdomains'}{$subdomain}{'files'}{$file}{'bandwidth'};
			$sites{$key}{'subdomains'}{$subdomain}{'files'}{$file}{'rank'} = $l;
			$projection = $bytes * $average;	
			$sites{$key}{'subdomains'}{$subdomain}{'files'}{$file}{'projectedbandwidth'} = $projection;
			$l++;
		}

		
		###SORT PORTS BY BANDWIDTH TO GET RANK###
		@ports = keys %{$sites{$key}{'subdomains'}{$subdomain}{'ports'}};
		
		$c = 0;
		@sortString = "";
		foreach $thingy (@ports)
		{
			$sortString[$c] = "$sites{$key}{'subdomains'}{$subdomain}{'ports'}{$thingy}{'bandwidth'} $thingy";
			$c++;			
		}
	
		@sorted = $sortRoutine_1n->(@sortString);
		
		$c = 0;
		foreach $thingy (@sorted)
		{
			@rcv = split(/\s/, $thingy);
			
			$ports[$c] = $rcv[1];
			$c++;
		}	
		
		######CALCULATE PORT INFORMATION FOR EACH SUBDOMAIN######
		$l = 1;
		foreach $port (@ports) {
			$bytes = $sites{$key}{'subdomains'}{$subdomain}{'ports'}{$port}{'bandwidth'};
			$sites{$key}{'subdomains'}{$subdomain}{'ports'}{$port}{'rank'} = $l;
			$projection = $bytes * $average;
			$sites{$key}{'subdomains'}{$subdomain}{'ports'}{$port}{'projectedbandwidth'} = $projection;
			$l++;
		}
	}
}

$stopTime = time;

$parseTime += ($stopTime - $startTime);

printf "done! took %d minutes %d seconds\n", int(($stopTime - $startTime)/60), ($stopTime - $startTime) % 60;


####################################################################
#Updating Profiles
####################################################################

print "Updating Profiles...";
$startTime = time;

foreach $key (@bandwidth)
{
	next if (!(-e "$PROFILESDIR$key"));
        $bandwidth = sprintf "%.2f", ($sites{$key}{'bandwidth'} / 1048576);
        $projected = sprintf "%.2f", ($sites{$key}{'projectedbandwidth'} / 1048576);
	ep("$PROFILESDIR$key", "\$bandwidth{'$bandwidthDate'}{'projected'}", "=", $projected);
	ep("$PROFILESDIR$key", "\$bandwidth{'$bandwidthDate'}{'actual'}", "=", $bandwidth);
}


$stopTime = time;

printf "done! took %d minutes %d seconds\n", int(($stopTime - $startTime)/60), ($stopTime - $startTime) % 60;


print "Outputing HTML pages...";
$startTime = time;

#####################################################################
#Get some miscellaneous data to be displayed
#####################################################################
$numserved = keys %sites;
$numusers = @users;
$numdomains = keys %lookup;
$endtime = '0';
chomp $endtime;
$totalminutes = int($parseTime / 60);
$totalseconds = $parseTime % 60;
#####################################################################
#Now we have to go through the tedious task of printing out our data#
#####################################################################

#####################################################################
#ALL USERS SUMMARY
#####################################################################

###OVERALL SUMMARY DATA PREPARATION###
$totalBytes = sprintf "%.2f", ($totalBytes / 1048576);
$totalProjectedBytes = sprintf "%.2f", ($totalProjectedBytes / 1048576);
$devRecvDisplay = sprintf "%.2f", ($devRecv / 1048576);
$devSendDisplay = sprintf "%.2f", ($devSend / 1048576);


$main_html .= qq~
<img src="/images/backgroundpixel.gif" width="500" height="1" border="0">
<a name="top"></a>
<font class="newssubject"><font size="4"><b><center>Hosted-Sites Summary For $FULLMONTH</center></b></font></font>
<br>
<br>
<table border="0" cellspacing="0" cellpadding="3">
<tr><td>
<a name="summary"><font class="newssubject"><b>General Summary</b></font></a>
<br><br><font class="content">(<b>Go To</b>: <a class="content" href="#top">Top</a>; General Summary; <a class="content" href="#sites">Top 100 Users by Bandwidth</a>; <a class="content" href="#sitesbyname">Users by Name</a>)</font><br><br>
</td></tr>
<tr><td>
<font class="content"><b>Analyzed from</b> $realLowDate <b>to</b> $realHighDate</font>
</td></tr>
<tr><td>
<font class="content">$totallines <b>lines analyzed in</b> $totalminutes <b>minutes</b> $totalseconds <b>seconds</b></font>
</td></tr>
<tr><td>
<font class="content"><b>Users signed up:</b> $numusers</font>
</td></tr>
<tr><td>
<font class="content"><b>Domains hosted:</b> $numdomains</font>
</td></tr>
<tr><td>
<font class="content"><b>Users served:</b> $numserved</font>
</td></tr>
<tr><td>
<font class="content"><b>MB Recieved:</b> $devRecvDisplay</font>
</td></tr>
<tr><td>
<font class="content"><b>MB Sent:</b> $devSendDisplay</font>
</td></tr>
<tr><td>
<font class="content"><b>Total MB Served:</b> $totalBytes</font>
</td></tr>
<tr><td>
<font class="content"><b>Projected MB Served:</b> $totalProjectedBytes</font>
</td></tr>
</table>
<br>
<br>
<a name="sitesbyname"><font class="newssubject"><b>Users Sorted by Name</b></font></a>
<br><br><font class="content">(<b>Go To</b>: <a class="content" href="#top">Top</a>; <a class="content" href="#summary">General Summary</a>; Users by Name; <a class="content" href="#sites">Top 100 Users by Bandwidth</a>)</font><br><br>
~;

$dir = $BW_OUTDIR . "letters/";
opendir(STUFF,$BW_OUTDIR . "letters");
@removeme = grep(!/^\.\.?/, readdir(STUFF));
closedir(STUFF);

foreach (@removeme) {
        unlink($dir.$_);
}

$lettersHTML .= qq~
<font class="newssubject"><font size="4"><b><center>Hosted-Sites Summary For $FULLMONTH</center></b></font></font>
<br>
<br>
<font class="newssubject"><b>Users Sorted by Name</b></font></a>
<br><br><font class="content">(<b>Go To</b>: <a class="content" href="$BW_OUTDIR_URL/stats.html"><b>&lt;Back to Hosted-Sites Summary</b></a>)</font><br><br>
~;
###PRINT QUICK-JUMP LETTERS###
$lastletter = 0;
foreach $key (@name)
{
	($thisletter) = ($key =~ /(^.)/);
	if ($thisletter ne $lastletter) {
                $displayletter = uc($thisletter);
                $main_html .= qq~<a class="link" href="$BW_OUTDIR_URL/letters/$displayletter.html">$displayletter</a> ~;
		$lettersHTML .= qq~<a class="link" href="$BW_OUTDIR_URL/letters/$displayletter.html">$displayletter</a> ~;
       }
	$lastletter = $thisletter;
}


$lettersHTML .= qq~
<br>
<TABLE border="0" cellspacing="0" cellpadding="3">
<TR bgcolor="#21364F"><TD><font class="content"><b>Rank</b></font></TD><TD><center><font class="content"><b>User</b></font></center></TD><TD><font class="content"><b>Used B/W(MB)</font></b></TD><TD><font class="content"><b>Projected B/W(MB)</b></font></TD></TR>~;

###PRINT USERS BY NAME###
$i = 0;
$printit = 0;
$lastletter = 0;
foreach $key (@name)
{
	$bg = ($i % 2 == 1) ? "415D7F" : "304761";
	##FORMAT RESULT
	$rank = $sites{$key}{'rank'};
	$bandwidth = sprintf "%.2f", ($sites{$key}{'bandwidth'} / 1048576);
        $projected = sprintf "%.2f", ($sites{$key}{'projectedbandwidth'} / 1048576);
	($thisletter) = ($key =~ /(^.)/);
	if ($thisletter ne $lastletter) {
		$displayletter = uc($thisletter);
		if ($printit == 1) {
			$lastdisplayletter = uc($lastletter);
			$letter_html .= qq~</table>~;	
			if(!open(OUTPUT, "> $BW_OUTDIR" . "letters/$lastdisplayletter.html"))
                	{ print "Can't open $lastdisplayletter.html\n";}
                	print OUTPUT $header_html;
	                print OUTPUT $letter_html;
	                print OUTPUT $footer_html;
        	        close(OUTPUT);
		} else {
			$printit = 1;
		}
		$letter_html = "";
		$letter_html = $lettersHTML . qq~<TR bgcolor="#253450"><TD colspan="4"><a name="$displayletter"><font class="newssubject">$displayletter</font></a></TD></TR>~;
	}
	$lastletter = $thisletter;
      	$letter_html .= qq~<TR bgcolor="#$bg"><TD><font class="content">$rank</font></TD><TD><font class="content"><a href="$BW_OUTDIR_URL/sites/$key.html">$key</a></font></TD><TD><font class="content">$bandwidth</font></TD><TD><font class="content">$projected</font></TD></TR>~;
	$i++;
}

$letter_html .= qq~</table>~;
if(!open(OUTPUT, ">$BW_OUTDIR" . "letters/$displayletter.html"))
{ print "Can't open $displayletter.html\n";}
print OUTPUT $header_html;
print OUTPUT $letter_html;
print OUTPUT $footer_html;
close(OUTPUT);

$main_html .= qq~
<br>
<br>
<a name="sites"><font class="newssubject"><b>Top 100 Users Sorted by Bandwidth</b></font></a>
<br><br><font class="content">(<b>Go To</b>: <a class="content" href="#top">Top</a>; <a class="content" href="#summary">General Summary</a>; <a class="content" href="#sitesbyname">Users by Name</a>; Top 100 Users by Bandwidth)</font><br><br>
<TABLE border="0" cellspacing="0" cellpadding="3">
<TR bgcolor="#21364F"><TD><font class="content"><b>Rank</b></font></TD><TD><center><font class="content"><b>User</b></font></center></TD><TD><font class="content"><b>Used B/W(MB)</font></b></TD><TD><font class="content"><b>Projected B/W(MB)</b></font></TD></TR>~;

###ALL USERS BY BANDWIDTH###
$i=0;
foreach $key (@bandwidth)
{
        last if ($i >= 100);
        $bg = ($i % 2 == 1) ? "415D7F" : "304761";
        ##FORMAT RESULT
        $rank = $sites{$key}{'rank'};
        $bandwidth = sprintf "%.2f", ($sites{$key}{'bandwidth'} / 1048576);
        $projected = sprintf "%.2f", ($sites{$key}{'projectedbandwidth'} / 1048576);
        $main_html .= qq~<TR bgcolor="#$bg"><TD><font class="content">$rank</font></TD><TD><font class="content"><a href="$BW_OUTDIR_URL/sites/$key.html">$key</a></font></TD><TD><font class="content">$bandwidth</font></TD><TD><font class="content">$projected</font></TD></TR>~;
        $i++;

}


$main_html .= qq~
</table>
~;

open(OUTPUT, "> $BW_OUTDIR" . "stats.html") || die "Can't open output file";
print OUTPUT $header_html;
print OUTPUT $main_html;
print OUTPUT $footer_html;

close(OUTPUT);

#####################################################################
#USER SUMMARY
#####################################################################

$dir = $BW_OUTDIR . "sites/";
opendir(STUFF,$BW_OUTDIR . "sites");
@removeme = grep(!/^\.\.?/, readdir(STUFF));
closedir(STUFF);

foreach (@removeme) {
        unlink($dir.$_);
}

foreach $key (keys %sites) {
	$main_html = "";
	###USER DATA PREPARATION###
	$bandwidth = sprintf "%.2f", ($sites{$key}{'bandwidth'} / 1048576);
        $projected = sprintf "%.2f", ($sites{$key}{'projectedbandwidth'} / 1048576);
	$numsubdomains = keys %{$sites{$key}{'subdomains'}};
	$main_html .= qq~
	<img src="/images/backgroundpixel.gif" width="700" height="1" border="0">
	<a name="top"></a>
	<font class="newssubject"><font size="4"><b><center>User - $key - Summary For $FULLMONTH</center></b></font></font>
	<br>
	<br>
	<table border="0" cellspacing="0" cellpadding="3">
	<tr><td>
	<a name="summary"><font class="newssubject"><b>General Summary</b></font></a>
	<br><br><font class="content">(<b>Go To</b>: <a class="content" href="#top">Top</a>; General Summary; <a class="content" href="#sites">Subdomains by Bandwidth</a>; <a class="content" href="#sitesbyname">Subdomains by Name</a>; <a class="content" href="$BW_OUTDIR_URL/stats.html"><b>&lt;Back to Hosted-Sites Summary</b></a>)</font><br><br>
	</td></tr>
	<tr><td>
	<font class="content"><b>Analyzed from</b> $realLowDate <b>to</b> $realHighDate</font>
	</td></tr>
	<tr><td>
        <font class="content"><b>Subdomains served:</b> $numsubdomains</font>
        </td></tr>
	<tr><td>
	<font class="content"><b>MB served:</b> $bandwidth</font>
	</td></tr>
	<tr><td>
	<font class="content"><b>Projected MB:</b> $projected</font>
	</td></tr>
	</table>
	<br>
	<br>
	<a name="50files"><font class="newssubject"><b>Subdomains Sorted by Bandwidth</b></font></a>
	<br><br><font class="content">(<b>Go To</b>: <a class="content" href="#top">Top</a>; <a class="content" href="#summary">General Summary</a>; Subdomains by Bandwidth; <a class="content" href="#sitesbyname">Subdomains by Name</a>; <a class="content" href="$BW_OUTDIR_URL/stats.html"><b>&lt;Back to Hosted-Sites Summary</b></a>)</font><br><br>
	<TABLE border="0" cellspacing="0" cellpadding="3">
	<TR bgcolor="#21364F"><TD><font class="content"><b>Rank</b></font></TD><TD><center><font class="content"><b>Name</b></font></center></TD><TD><font class="content"><b>Used B/W(MB)</font></b></TD><TD><font class="content"><b>Projected B/W(MB)</b></font></TD></TR>~;

	###SORT SUBDOMAINS BY BANDWIDTH###
	@subdomains = keys %{$sites{$key}{'subdomains'}};
	
	$c = 0;
	@sortString="";
	foreach $thingy (@subdomains)
	{
		$sortString[$c] = "$sites{$key}{'subdomains'}{$thingy}{'bandwidth'} $thingy";
		$c++;			
	}
	
	#@sorted = fieldsort ['-1n'], @sortString;
	@sorted = $sortRoutine_1n->(@sortString);
	
	$c = 0;
	foreach $thingy (@sorted)
	{
		@rcv = split(/\s/, $thingy);
		
		$subdomains[$c] = $rcv[1];
		$c++;
	}
	
	###PRINT SUBDOMAINS BY BANDWIDTH###
	$i = 0;
	foreach $subdomain (@subdomains) {
		$bg = ($i % 2 == 1) ? "415D7F" : "304761";
		$rank = $sites{$key}{'subdomains'}{$subdomain}{'rank'};
		$bandwidth = sprintf "%.2f", ($sites{$key}{'subdomains'}{$subdomain}{'bandwidth'} / 1048576);
                $projected = sprintf "%.2f", ($sites{$key}{'subdomains'}{$subdomain}{'projectedbandwidth'} / 1048576);
		$subdomainHTML = $subdomain;
		if ($subdomain ne "ftp") {
			$subdomainHTML = qq~<a href="$BW_OUTDIR_URL/sites/$key-$subdomain.html">$subdomain</a>~;
		}
		$main_html .= qq~<TR bgcolor="#$bg"><TD><font class="content">$rank</font></TD><TD><font class="content">$subdomainHTML</font></font></TD><TD><font class="content">$bandwidth</font></TD><TD><font class="content">$projected</font></TD></TR>~;
		$i++;
	}

	###SORT SUBDOMAINS BY NAME###
	
	$c = 0;
	@sortString="";
	foreach $thingy (@subdomains)
	{
		$sortString[$c] = $thingy;
		$c++;			
	}
	
	#@sorted = fieldsort ['1'], @sortString;
	
	@sorted = $sortRoutine_1->(@sortString);
	
	$c = 0;
	foreach $thingy (@sorted)
	{
		$subdomains[$c] = $thingy;
		$c++;
	}
	
	$main_html .= qq~
	</table>
	<br>
	<br>
	<a name="sitesbyname"><font class="newssubject"><b>Subdomains Sorted by Name</b></font></a>
	<br><br><font class="content">(<b>Go To</b>: <a class="content" href="#top">Top</a>; <a class="content" href="#summary">General Summary</a>; <a class="content" href="#sites">Subdomains by Bandwidth</a>; Subdomains by Name; <a class="content" href="$BW_OUTDIR_URL/stats.html"><b>&lt;Back to Hosted-Sites Summary</b></a>)</font><br><br>
	~;

	###PRINT QUICK-JUMP LETTERS###
	$lastletter = 0;
	foreach $subdomain (@subdomains)
	{
		($thisletter) = ($subdomain =~ /(^.)/);
		if ($thisletter ne $lastletter) {
          	      $displayletter = uc($thisletter);
         	       $main_html .= qq~<a class="link" href="#$displayletter">$displayletter</a> ~;
       		}
		$lastletter = $thisletter;
	}

	$main_html .= qq~
	<br>
	<TABLE border="0" cellspacing="0" cellpadding="3">
	<TR bgcolor="#21364F"><TD><font class="content"><b>Rank</b></font></TD><TD><center><font class="content"><b>Name</b></font></center></TD><TD><font class="content"><b>Used B/W(MB)</font></b></TD><TD><font class="content"><b>Projected B/W(MB)</b></font></TD></TR>~;
	###PRINT SUBDOMAINS BY NAME###
	$i = 0;
	$lastletter = 0;
	foreach $subdomain (@subdomains)
	{
		$bg = ($i % 2 == 1) ? "415D7F" : "304761";
		##FORMAT RESULT
		$rank = $sites{$key}{'subdomains'}{$subdomain}{'rank'};
		$bandwidth = sprintf "%.2f", ($sites{$key}{'subdomains'}{$subdomain}{'bandwidth'} / 1048576);
        	$projected = sprintf "%.2f", ($sites{$key}{'subdomains'}{$subdomain}{'projectedbandwidth'} / 1048576);
		($thisletter) = ($subdomain =~ /(^.)/);
		if ($thisletter ne $lastletter) {
			$displayletter = uc($thisletter);
			$main_html .= qq~<TR bgcolor="#253450"><TD colspan="4"><a name="$displayletter"><font class="newssubject">$displayletter</font></a><font class="content">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;(Back to: <a href="#sitesbyname">Subdomains by Name</a>)</font></TD></TR>~;
		}
		$lastletter = $thisletter;
		$subdomainHTML = $subdomain;
                if ($subdomain ne "ftp") {
                        $subdomainHTML = qq~<a href="$BW_OUTDIR_URL/sites/$key-$subdomain.html">$subdomain</a>~;
                }
      		$main_html .= qq~<TR bgcolor="#$bg"><TD><font class="content">$rank</font></TD><TD><font class="content">$subdomainHTML</font></TD><TD><font class="content">$bandwidth</font></TD><TD><font class="content">$projected</font></TD></TR>~;
		$i++;
	}

	$main_html .= qq~
	</table>
	~;

	if(!open(OUTPUT, ">$BW_OUTDIR" . "sites/$key.html"))
	{ print "Can't open $key\n";}
	print OUTPUT $header_html;
	print OUTPUT $main_html;
	print OUTPUT $footer_html;
	close(OUTPUT);
}

#####################################################################
#SUBDOMAIN SUMMARY
#####################################################################

foreach $key (keys %sites) {
	foreach $subdomain (keys %{$sites{$key}{'subdomains'}}) {
		next if ($subdomain eq "ftp");
		$main_html = "";
		###SUBDOMAIN DATA PREPARATION###
		$bandwidth = sprintf "%.2f", ($sites{$key}{'subdomains'}{$subdomain}{'bandwidth'} / 1048576);
                $projected = sprintf "%.2f", ($sites{$key}{'subdomains'}{$subdomain}{'projectedbandwidth'} / 1048576);
		if ($subdomain ne "other") {
		$numfiles = keys %{$sites{$key}{'subdomains'}{$subdomain}{'files'}};
		$main_html .= qq~
		<img src="/images/backgroundpixel.gif" width="700" height="1" border="0">
		<a name="top"></a>
		<font class="newssubject"><font size="4"><b><center>Subdomain - $subdomain - Summary For $FULLMONTH</center></b></font></font>
		<br>
		<br>
		<table border="0" cellspacing="0" cellpadding="3">
		<tr><td>
		<a name="summary"><font class="newssubject"><b>General Summary</b></font></a>
		<br><br><font class="content">(<b>Go To</b>: <a class="content" href="#top">Top</a>; General Summary; <a class="content" href="#100files">Top 100 Files by Bandwidth</a>; <a class="content" href="$BW_OUTDIR_URL/sites/$key.html"><b>&lt;Back to User Summary</b></a>; <a class="content" href="$BW_OUTDIR_URL/stats.html"><b>&lt;&lt;Back to Hosted-Sites Summary</b></a>)</font><br><br>
		</td></tr>
		<tr><td>
		<font class="content"><b>Analyzed from</b> $realLowDate <b>to</b> $realHighDate</font>
		</td></tr>
		<tr><td>
                <font class="content"><b>Files served:</b> $numfiles</font>
                </td></tr>
		<tr><td>
		<font class="content"><b>MB served:</b> $bandwidth</font>
		</td></tr>
		<tr><td>
		<font class="content"><b>Projected MB:</b> $projected</font>
		</td></tr>
		</table>
		<br>
		<br>
		<a name="100files"><font class="newssubject"><b>Top 100 Files Sorted by Bandwidth</b></font></a>
		<br><br><font class="content">(<b>Go To</b>: <a class="content" href="#top">Top</a>; <a class="content" href="#summary">General Summary</a>; Top 100 Files by Bandwidth; <a class="content" href="$BW_OUTDIR_URL/sites/$key.html"><b>&lt;Back to User Summary</b></a>; <a class="content" href="$BW_OUTDIR_URL/stats.html"><b>&lt;&lt;Back to Hosted-Sites Summary</b></a>)</font><br><br>
		<TABLE border="0" cellspacing="0" cellpadding="3">
		<TR bgcolor="#21364F"><TD><font class="content"><b>Rank</b></font></TD><TD><center><font class="content"><b>File</b></font></center></TD><TD><font class="content"><b>Used B/W(MB)</font></b></TD><TD><font class="content"><b>Projected B/W(MB)</b></font></TD><TD><font class="content"><b>Hits</font></b></TD></TR>~;

		###SORT FILES BY BANDWIDTH TO DISPLAY###
		@files = keys %{$sites{$key}{'subdomains'}{$subdomain}{'files'}};
		$c = 0;
		@sortString="";
		foreach $thingy (@files)
		{
			$sortString[$c] = "$sites{$key}{'subdomains'}{$subdomain}{'files'}{$thingy}{'bandwidth'} $thingy";
			$c++;			
		}
	
		#@sorted = fieldsort ['-1n'], @sortString;
		@sorted = $sortRoutine_1n->(@sortString);
		
		$c = 0;
		foreach $thingy (@sorted)
		{
			@rcv = split(/\s/, $thingy);
			
			$files[$c] = $rcv[1];
			$c++;
		}
		
		$i = 0;
		foreach $file (@files) {
			if ($i >= 100) {
				last;
			}
			###FILE DATA PREPARATION###
			$bg = ($i % 2 == 1) ? "415D7F" : "304761";
			$rank = $sites{$key}{'subdomains'}{$subdomain}{'files'}{$file}{'rank'};
			$bandwidth = sprintf "%.2f", ($sites{$key}{'subdomains'}{$subdomain}{'files'}{$file}{'bandwidth'} / 1048576);
      			$projected = sprintf "%.2f", ($sites{$key}{'subdomains'}{$subdomain}{'files'}{$file}{'projectedbandwidth'} / 1048576);
			$hits = $sites{$key}{'subdomains'}{$subdomain}{'files'}{$file}{'hits'};
			$main_html .= qq~<TR bgcolor="#$bg"><TD><font class="content">$rank</font></TD><TD><font class="content"><a href="http://$subdomain$file">http://$subdomain$file</a></font></font></TD><TD><font class="content">$bandwidth</font></TD><TD><font class="content">$projected</font></TD><TD><font class="content">$hits</font></TD></TR>~;
			$i++;
		}
		$main_html .= qq~
		</table>
		~;
		} else {
		
		$numports = keys %{$sites{$key}{'subdomains'}{$subdomain}{'ports'}};
		$main_html .= qq~
		<img src="/images/backgroundpixel.gif" width="700" height="1" border="0">
		<a name="top"></a>
		<font class="newssubject"><font size="4"><b><center>Subdomain - $subdomain - Summary For $FULLMONTH</center></b></font></font>
		<br>
		<br>
		<table border="0" cellspacing="0" cellpadding="3">
		<tr><td>
		<a name="summary"><font class="newssubject"><b>General Summary</b></font></a>
		<br><br><font class="content">(<b>Go To</b>: <a class="content" href="#top">Top</a>; General Summary; <a class="content" href="#100ports">Top 100 Ports by Bandwidth</a>; <a class="content" href="$BW_OUTDIR_URL/sites/$key.html"><b>&lt;Back to User Summary</b></a>; <a class="content" href="$BW_OUTDIR_URL/stats.html"><b>&lt;&lt;Back to Hosted-Sites Summary</b></a>)</font><br><br>
		</td></tr>
		<tr><td>
		<font class="content"><b>Analyzed from</b> $realLowDate <b>to</b> $realHighDate</font>
		</td></tr>
		<tr><td>
                <font class="content"><b>Ports served:</b> $numports</font>
                </td></tr>
		<tr><td>
		<font class="content"><b>MB served:</b> $bandwidth</font>
		</td></tr>
		<tr><td>
		<font class="content"><b>Projected MB:</b> $projected</font>
		</td></tr>
		</table>
		<br>
		<br>
		<a name="100ports"><font class="newssubject"><b>Top 100 Ports Sorted by Bandwidth</b></font></a>
		<br><br><font class="content">(<b>Go To</b>: <a class="content" href="#top">Top</a>; <a class="content" href="#summary">General Summary</a>; Top 100 Ports by Bandwidth; <a class="content" href="$BW_OUTDIR_URL/sites/$key.html"><b>&lt;Back to User Summary</b></a>; <a class="content" href="$BW_OUTDIR_URL/stats.html"><b>&lt;&lt;Back to Hosted-Sites Summary</b></a>)</font><br><br>
		<TABLE border="0" cellspacing="0" cellpadding="3">
		<TR bgcolor="#21364F"><TD><font class="content"><b>Rank</b></font></TD><TD><center><font class="content"><b>Port</b></font></center></TD><TD><font class="content"><b>Used B/W(MB)</font></b></TD><TD><font class="content"><b>Projected B/W(MB)</b></font></TD></TR>~;

		###SORT PORTS BY BANDWIDTH TO DISPLAY###
		@ports = keys %{$sites{$key}{'subdomains'}{$subdomain}{'ports'}};
		$c = 0;
		@sortString="";
		foreach $thingy (@ports)
		{
			$sortString[$c] = "$sites{$key}{'subdomains'}{$subdomain}{'ports'}{$thingy}{'bandwidth'} $thingy";
			$c++;			
		}
	
		#@sorted = fieldsort ['-1n'], @sortString;
		@sorted = $sortRoutine_1n->(@sortString);
		
		$c = 0;
		foreach $thingy (@sorted)
		{
			@rcv = split(/\s/, $thingy);
			
			$ports[$c] = $rcv[1];
			$c++;
		}
		
		$i = 0;
		foreach $port (@ports) {
			if ($i >= 100) {
				last;
			}
			###PORT DATA PREPARATION###
			$bg = ($i % 2 == 1) ? "415D7F" : "304761";
			$rank = $sites{$key}{'subdomains'}{$subdomain}{'ports'}{$port}{'rank'};
			$bandwidth = sprintf "%.2f", ($sites{$key}{'subdomains'}{$subdomain}{'ports'}{$port}{'bandwidth'} / 1048576);
      			$projected = sprintf "%.2f", ($sites{$key}{'subdomains'}{$subdomain}{'ports'}{$port}{'projectedbandwidth'} / 1048576);
			$main_html .= qq~<TR bgcolor="#$bg"><TD><font class="content">$rank</font></TD><TD><font class="content">$port</font></TD><TD><font class="content">$bandwidth</font></TD><TD><font class="content">$projected</font></TD></TR>~;
			$i++;
		}
		$main_html .= qq~
		</table>
		~;
		}
		if(!open(OUTPUT, "> $BW_OUTDIR" . "sites/$key-$subdomain.html"))
		{ print "Can't open $key-$subdomain output file\n";next;}
		print OUTPUT $header_html;
		print OUTPUT $main_html;
		print OUTPUT $footer_html;
		close(OUTPUT);
	}
}

$stopTime = time;

printf "done! took %d minutes %d seconds\n", int(($stopTime - $startTime)/60), ($stopTime - $startTime) % 60;

printf "Setting Permissions...";

$startTime = time;
system("chmod -R 750 $BW_OUTDIR");
system("chown -R webadmin.nobody $BW_OUTDIR");
$stopTime = time;

printf "done! took %d minutes %d seconds\n", int(($stopTime - $startTime)/60), ($stopTime - $startTime) % 60;

printf "Running buttfuck...";

$startTime = time;
system("/usr/bin/perl /root/buttfuck.pl > /dev/null 2>&1");
$stopTime = time;

printf "done! took %d minutes %d seconds\n", int(($stopTime - $startTime)/60), ($stopTime - $startTime) % 60;

unlink("/root/bandwidth.run");

#####################################################################
#END OF PROGRAM
#####################################################################

#####################################################################
#SUBROUTINES
#####################################################################
sub getHighDay {
	$month = shift;
	if ($month eq "Feb") {
		return 28;	
	} elsif ($month eq "Jan" || $month eq "May" || $month eq "Jul" || $month eq "Aug" || $month eq "Oct" || $month eq "Dec") {
		return 31;
	} else {
		return 30;
	}
}

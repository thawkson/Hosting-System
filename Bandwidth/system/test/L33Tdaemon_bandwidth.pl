#!/usr/bin/perl

#################################################################
#                      L33t.ca Bandwidth Script                 #
#                               2.0                             #
#       							#
#    Keeps track of bandwidth by extracting data from		#
#    a collection of logs, which are parsed using modules.	#
#    I'll document this better when I get if finished.		#
#								#
#    L33t.ca, August 2002 					#
#								#
#################################################################


#####
##Include Special Libraries
#####

require("L33Tsystem_config.inc"); ## L33t System Variables...

require("L33Tsystem_library.inc"); ## L33t System API...

require("bw/L33Tbandwidth_vars.inc"); ## Bandwidth system specific variables


L33TBW_Log( "=====================================\n" );
L33TBW_Log( "L33T System Bandwidth Daemon, Ver 1.0\n" );
L33TBW_Log( "=====================================\n" );


$firstRun = 1;


###Load in our modules

L33TBW_Log( "Loading in parsing modules.....\n");

opendir(MODDIR, "bw/");
	@moduleFiles = grep(/\.mod$/, readdir(MODDIR));
closedir(MODDIR);

foreach $module (@moduleFiles)
{
	L33TBW_Log( "Loading $module module.....\n" );
	require("bw/$module") || die("Error including module $module\n");
}

L33TBW_CheckTable();

## This is the part where we would load in our save file
## TODO : Add in the stuff to load the save file from mySQL

## For now, we'll just change the data structure the way the savefile would

L33TBW_Log( "Loading save file.....\n" );

$dbh = L33T_ConnectToDatabase($config{'dbname'}, $config{'dbuser'}, $config{'dbpass'});

$sth = $dbh->prepare("SELECT * FROM $config{'bandwidth_dbname'}_save");

$sth->execute();

## There SHOULDN'T be more than 1 row, but just in case
## We'll assume it's the last row....

while($hash_ref = $sth->fetchrow_hashref)
{
        foreach $ss (keys(%{$hash_ref}))
	{
		if( $ss eq 'lastrun')
		{ next; }

		$BW_CONFIG{$ss}{'LAST_LINE'} = $hash_ref->{$ss};
	}
}
		
$dbh->disconnect();

###
### START OF DAEMONIZED CODE!!!!
###

L33TBW_Log("Entering Daemonized Code.....\n");


while(1)
{

undef(%tally);

## Go through every module and parse and record the bandwidth that
## went through that sub-system

foreach $subSystem (keys(%BW_CONFIG))
{

	L33TBW_Log( "Beginning to parse $subSystem data.....\n" );

	## Load in the files we have to parse.. (these will be in chronological order)

	eval(qq~\@{\$BW_CONFIG{$subSystem}{'FILE_LIST'}} = $BW_CONFIG{$subSystem}{'FILENAME_FUNCTION'}()~);
	
	$switch = 1;
	foreach $file (@{$BW_CONFIG{$subSystem}{'FILE_LIST'}})
	{
		if( L33TBW_ShouldParseFile($file, $subSystem))
		{
			## Load 'er up, and start parsing
			## Yup unfortunatly, we have to load in the whole file...
			## TODO : Remind users that having monolithic log files is *BAD*
			
			L33TBW_Log( "Parsing $file.....\n");
			
			open( IN, $file);
				@fileData = reverse <IN>;
			close(IN);

			
			$numLines = 0;
			
			foreach $line (@fileData)
			{
				$numLines++;
				
				chomp($line);
				
				if($switch)
				{
					$lastLine = $line;
					$switch = 0;
				}
				
				if( $line eq "")
				{
					next;
				}
				
				if( $BW_CONFIG{$subSystem}{'LAST_LINE'} eq $line)
				{
					last;
				}

				if(!$firstRun)
				{
					usleep(10);
				}

				eval(qq~\@lineData = $BW_CONFIG{$subSystem}{'PARSE_FUNCTION'}(\$line)~);

				@transferDate = L33T_EpochToTime($lineData[$BW_FIELD_TIME]);
								
				$tally{$lineData[$BW_FIELD_USER]}{$subSystem}{$transferDate[0]}{$transferDate[1]}{$transferDate[2]} += $lineData[$BW_FIELD_BANDWIDTH];	
			}

			L33TBW_Log("Parsed $numLines lines.....\n");
			
			undef(@fileData);
		}
	}
	
	$BW_CONFIG{$subSystem}{'LAST_LINE'} = $lastLine;
}


##### OUTPUT USER DATA TO MYSQL TABLE####################################################################

L33TBW_Log( "Writting data to MySQL table $config{'bandwidth_dbname'}.....\n" );

L33TBW_Log( "Connecting to database.....\n" );

$dbh = L33T_ConnectToDatabase($config{'dbname'}, $config{'dbuser'}, $config{'dbpass'});

OUTER: foreach $user (keys(%tally))
{

	$sth = $dbh->prepare("SELECT * FROM $config{'bandwidth_dbname'} WHERE username = " . $dbh->quote("".$user));

	## If this user exists already, merge his data with the tally hash
	
	$exists = 0;
	if($sth->execute() ne "0E0")
	{
		L33TBW_MergeData( $sth->fetchrow_arrayref() );
		
		$exists = 1;
	}

	$sth->finish();

	$out = "";
	foreach $ss (keys(%{$tally{$user}}))
	{
		foreach $year (keys(%{$tally{$user}{$ss}}))
		{
			foreach $month (keys(%{$tally{$user}{$ss}{$year}}))
			{
				foreach $day (keys(%{$tally{$user}{$ss}{$year}{$month}}))
				{
					#TODO : Remove this garbage filter......
					
					if( $tally{$user}{$ss}{$year}{$month}{$day} > 10000 )
					{
						$out .= "$year $month $day $tally{$user}{$ss}{$year}{$month}{$day}\n";
					}
					else
					{
						next OUTER;
					}
				}
			}
		}
	
		L33TBW_Log( "Updating $user.....\n" );

		if(!$exists)
		{
			$statement = "INSERT INTO $config{'bandwidth_dbname'} (username) VALUES (" . $dbh->quote("".$user) . ")";
			
			$dbh->do($statement);
		}		

		$statement = "UPDATE $config{'bandwidth_dbname'} SET $ss = " . $dbh->quote("".$out) . " WHERE username = " . $dbh->quote("".$user);

		$dbh->do($statement);
	}
}

### Write all the save file stuff out.....

L33TBW_Log("Writting save file.....\n");

$saveTable = $config{'bandwidth_dbname'} . "_save";

$dbh->do( "DELETE FROM $saveTable");

$dbh->do( "INSERT INTO $saveTable (lastrun) VALUES (" . time . ")");

foreach $ss (keys(%BW_CONFIG))
{
	$dbh->do("UPDATE $saveTable SET $ss = " . $dbh->quote("".$BW_CONFIG{$ss}{'LAST_LINE'}) );
}

$dbh->disconnect();


###
### END OF DAEMONIZED CODE
###

$firstRun = 0;

L33TBW_Log("Waiting $config{'bandwidth_delay'} seconds.....\n");

sleep($config{'bandwidth_delay'});
}







##### FUNCTIONS##########################################################################################


### Merges a reference to an array with the current tally hash
###
sub L33TBW_MergeData
{
	$u = shift;
	
	my(@subSys) = keys(%{$tally{$user}});
		
	my($i);
	for $i (1 .. $#{$u})
	{
		foreach (split(/\n/, $u->[$i]))
		{
			my($year, $month, $day, $bw) = (/(\d+) (\d+) (\d+) (\d+)/);

			$tally{$user}{$subSys[$i-1]}{$year}{$month}{$day} += $bw;
		}
	}
}

### I'm thinking that later on we could have some sort
### of running text file that will have a log of what the 
### bw script is doing, that will be viewable from the web...
sub L33TBW_Log
{
	## TODO : Implement this magic 'Log'
	print "$_[0]";
}

### Just a lot of shit that I don't want cluttering up the main block of code...
### All it does is make sure that the database is setup correctly and has the right
### columns and stuff....
sub L33TBW_CheckTable
{
	$dbh = L33T_ConnectToDatabase($config{'dbname'}, $config{'dbuser'}, $config{'dbpass'});

		
	### TABLE AND COLUMN CHECK FOR THE USER TABLE

	L33TBW_Log("Checking for user data table.....\n");

	if(!L33TBW_TableSearch($config{'bandwidth_dbname'}))
	{
		L33TBW_Log( "Table not found in database, creating now.....\n" );
	
		$dbh->do( qq~ CREATE TABLE `$config{'bandwidth_dbname'}` (
				`username` MEDIUMTEXT NOT NULL) ~) or die "Can't create table....";
	}
	
	
	L33TBW_Log("Checking proper columns in user table.....\n");
	
	foreach $sys (keys(%BW_CONFIG))
	{
		if(!L33TBW_ColumnSearch($config{'bandwidth_dbname'}, $sys))
		{
		        print "Adding column $sys to table...\n";
			$dbh->do( qq~ ALTER TABLE `$config{'dbname'}`.`$config{'bandwidth_dbname'}` ADD `$sys` LONGTEXT ~ );
		}
	}


	### TABLE AND COLUMN CHECK FOR SAVE FILE TABLE

	L33TBW_Log("Checking for save table.....\n");

	$saveName = $config{'bandwidth_dbname'} . "_save";

	if(!L33TBW_TableSearch($saveName))
	{
		L33TBW_Log( "Table not found in database, creating now.....\n" );
	
		$dbh->do( qq~ CREATE TABLE `$saveName` (
				`lastrun` MEDIUMTEXT NOT NULL) ~) or die "Can't create table....";
	}
	
	
	L33TBW_Log("Checking proper columns in save table.....\n");
	
	foreach $sys (keys(%BW_CONFIG))
	{
		if(!L33TBW_ColumnSearch($saveName, $sys))
		{
		        print "Adding column $sys to table...\n";
			$dbh->do( qq~ ALTER TABLE `$config{'dbname'}`.`$saveName` ADD `$sys` LONGTEXT ~ );
		}
	}

	$sth->finish();

	$dbh->disconnect();
}


sub L33TBW_ColumnSearch
{
	my($table, $col) = @_;

	my($dbh) = L33T_ConnectToDatabase($config{'dbname'}, $config{'dbuser'}, $config{'dbpass'});

	$sth = $dbh->prepare("SHOW COLUMNS FROM $table");
	
	$sth->execute();
	
	$tmp = 0;
	while(@row = $sth->fetchrow_array())
	{
	        $tmp = 1 if($row[0] =~ /^$col$/);
	}

	$sth->finish();

	$dbh->disconnect();

return($tmp);
}


sub L33TBW_TableSearch
{
	my($dbh) = L33T_ConnectToDatabase($config{'dbname'}, $config{'dbuser'}, $config{'dbpass'});
	
	my($sth) = $dbh->prepare("SHOW TABLES");

	$sth->execute();

	$tmp = 0;
	my($ss) = shift;
	while(@row = $sth->fetchrow_array())
	{
		$tmp = 1 if($ss =~/^$row[0]$/);
	}
	
	$sth->finish();
	$dbh->disconnect();

return($tmp);
}


## File::Tail is a piece of shit
sub L33TBW_ShouldParseFile
{

	my($file, $ss) = @_;

	my($in, @lastLine, @saveLine);

	if( $BW_CONFIG{$ss}{'LAST_LINE'} eq "")
	{
		return(1);
	}
	else
	{
		eval(qq~\@lastLine = $BW_CONFIG{$ss}{'PARSE_FUNCTION'}(L33TBW_GetLastLine(\$file))~);
		eval(qq~\@saveLine = $BW_CONFIG{$ss}{'PARSE_FUNCTION'}(\$BW_CONFIG{$subSystem}{'LAST_LINE'})~);

		if( $lastLine[$BW_FIELD_TIME] >= $saveLine[$BW_FIELD_TIME])
		{
			return(1);
		}
		
	}
	
return(0);	
}


## Gets the last line of a file
## Arguments : Full path to file
sub L33TBW_GetLastLine
{

	my($file) = $_[0];

	my($lastLine);

	open(IN, $file);

	
	## read() is a really really slow function
	## This is from the old bandwidth script, but
	## it seems to be the only thing that works well
	## TODO : Come up with a cleaner solution.

	seek( IN, ((-s $file) - 2500), 0);

	while(!eof(IN))
	{
		$lastLine = <IN>;
	}

	close(IN);

return($lastLine);
}



## Debug stuff, see what the modules are passing in....

sub L33TBW_DebugDump
{

	foreach $key (keys( %BW_CONFIG ) )
	{
		print "\n$key\n";
		print "==============\n";
		print "PARSE_FUNCTION \t $BW_CONFIG{$key}{'PARSE_FUNCTION'}\n";
		print "FILENAME_FUNCTION \t $BW_CONFIG{$key}{'FILENAME_FUNCTION'}\n";
		print "FILE_LIST\n";

		foreach ( @{$BW_CONFIG{$key}{'FILE_LIST'}})
		{
			print "\t$_\n";
		}
	}

	print "\n";

}



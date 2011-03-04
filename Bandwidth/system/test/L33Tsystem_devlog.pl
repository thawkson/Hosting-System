#!/usr/bin/perl

$0 = "L33Tsystem_devlog";

require "/root/L33Tsystem/L33Tsystem_config.inc";
require "/root/L33Tsystem/L33Tsystem_library.inc";

#Load MySQL config data for this program
&getConfig;

&parsedev;

&writelog;

sub getConfig {
	$config_dl{'proc_uptime'} = "/proc/uptime";
	$config_dl{'proc_net_dev'} = "/proc/net/dev";
	$config_dl{'log_file'} = "/var/log/devlog";
	$config_dl{'wrap_bytes'} = 4294967296;
	$time = time;
	$first_find = 1;
	open UPTIME,$config_dl{'proc_uptime'};
	foreach (<UPTIME>) {
		@uptime = split /\s+/;
	}
	close UPTIME;
	$uptime = $time - int($uptime[0]);
	open LOG, $config_dl{'log_file'};
	foreach (reverse <LOG>) {
		($date, $logUptime, $dev, $r_total_bytes, $t_total_bytes) = split /\s+/;
		if ($first_find) {
			$lastDate = $date;
			$lastUptime = $logUptime;
			$first_find = 0;
		}
		if ($lastDate != $date) {
			last;
		}
		$lastLog{$dev}{'r_bytes'} = $r_total_bytes;
		$lastLog{$dev}{'t_bytes'} = $t_total_bytes;
	}
	close LOG;
}

sub parsedev {
	$first = 2;
	open DEV, $config_dl{'proc_net_dev'};
	foreach (<DEV>) {
		if ($first) {
			$first--;
			next;
		}
		@stuff = split /:/;
		$stuff[1] =~ s/^\s+//;
		@stuff2 = split /\s+/, $stuff[1];
		($dev) = $stuff[0] =~ /(\w+)/;
		$log{$dev}{'r_total_bytes'} = $stuff2[0];
		$log{$dev}{'t_total_bytes'} = $stuff2[8];
		
		#check if server has been rebooted
		if ($uptime > $lastUptime + 10) {  #account for any small errors in uptime calculation
			$log{$dev}{'r_bytes'} = $log{$dev}{'r_total_bytes'};
			
		#check if the number wrapped
		} elsif ($log{$dev}{'r_total_bytes'} < $lastLog{$dev}{'r_bytes'}) {
			$log{$dev}{'r_bytes'} = $log{$dev}{'r_total_bytes'} - $lastLog{$dev}{'r_bytes'} + $config_dl{'wrap_bytes'};
		} else {
			$log{$dev}{'r_bytes'} = $log{$dev}{'r_total_bytes'} - $lastLog{$dev}{'r_bytes'};
		}
		
		if ($uptime > $lastUptime + 10) {
			$log{$dev}{'t_bytes'} = $log{$dev}{'t_total_bytes'};
		} elsif ($log{$dev}{'t_total_bytes'} < $lastLog{$dev}{'t_bytes'}) {
			$log{$dev}{'t_bytes'} = $log{$dev}{'t_total_bytes'} - $lastLog{$dev}{'t_bytes'} + $config_dl{'wrap_bytes'};
		} else {
			$log{$dev}{'t_bytes'} = $log{$dev}{'t_total_bytes'} - $lastLog{$dev}{'t_bytes'};
		}
	}
	close DEV;
}

sub writelog {
	open LOG, ">> $config_dl{'log_file'}";
	L33T_Lock(LOG);
	foreach $dev (keys %log) {
		print LOG "$time $uptime $dev $log{$dev}{'r_total_bytes'} $log{$dev}{'t_total_bytes'} $log{$dev}{'r_bytes'} $log{$dev}{'t_bytes'}\n";
	}
	L33T_Unlock(LOG);
	close LOG;
}

#!/usr/bin/perl

#Captures packets and traces bandwidth usage back to the user
#and updates a log file

$0 = "L33Tdaemon_packetlog";

use Net::Pcap;
use Time::HiRes qw(time usleep);

require "/root/L33Tsystem/L33Tsystem_config.inc";
require "/root/L33Tsystem/L33Tsystem_library.inc";

#Program already running?
L33T_ProcCheck("L33Tdaemon_packetlog");

#Load modules
L33T_GetModules("/root/L33Tsystem/packetlog", "L33Tpacketlog");

#Load MySQL config data for this program and modules
&getConfig;

#Apply packet filter and listen on interface, running &process_pkt for every packet found
$pcap_t = Net::Pcap::open_live($config_pl{'init_interface'},$config_pl{'init_snapSize'}, $config_pl{'init_promis'}, $config_pl{'init_timeout'}, \$err);
Net::Pcap::compile($pcap_t, \$filter_t,$config_pl{'filter_string'},1,$config_pl{'filter_netmask'});
Net::Pcap::setfilter($pcap_t, $filter_t);
Net::Pcap::loop($pcap_t, -1, \&process_pkt, "");
Net::Pcap::close($pcap_t);


sub getConfig {
	my (@ip,@hooks);
	
	#TODO: This data should come from mySQL
	
	$config_pl{'init_interface'} = "eth0";
	$config_pl{'init_snapSize'} = 68;
	$config_pl{'init_promis'} = 0;
	$config_pl{'init_timeout'} = 2000;
	$config_pl{'filter_string'} = "not port 80";
	$config_pl{'filter_netmask'} = "255.255.255.0";
	$config_pl{'$log_update_timeout'} = 300;
	$config_pl{'$log_file'} = "/var/log/packetlog";
	$config_pl{'$lock_file'} = "/root/L33Tsystem/L33Tpacketlog.lock";
	$config_pl{'local_ips'}{'209.167.201.128'} = 1;
	$config_pl{'local_ips'}{'209.167.201.129'} = 1;
	$config_pl{'local_ips'}{'209.167.201.130'} = 1;
	$config_pl{'local_ips'}{'209.167.201.131'} = 1;
	$config_pl{'local_ips'}{'209.167.201.132'} = 1;
	$config_pl{'local_ips'}{'209.167.201.133'} = 1;
	$config_pl{'local_ips'}{'209.167.201.134'} = 1;
	$config_pl{'local_ips'}{'209.167.201.135'} = 1;
	$config_pl{'local_ips'}{'127.0.0.1'} = 1;
	$config_pl{'local_ips'}{'0.0.0.0'} = 1;

	#convert config ips into format found in /proc/net/tcp
	#Takes A.B.C.D string and converts to DCBA in hex
	foreach (keys %{$config_pl{'local_ips'}}) {
		@ip = split /\./;
		$ip_string = unpack("H*",pack("C",$ip[3])).unpack("H*",pack("C",$ip[2])).unpack("H*",pack("C",$ip[1])).unpack("H*", pack("C",$ip[0]));
		$local_ips_tr{$ip_string} = 1;
	}

	## HOOK: getConfig
	## Desc: This is where modules can load mysql config data and other config data
	@hooks = L33T_GetHooks("L33Tpacketlog","getConfig"); foreach (@hooks) { &{$_}; }
}

sub process_pkt {
	my($user_data, $hdr, $pkt) = @_;
	my (@hooks, $protocol, $src_ip, $dest_ip, $uid, $local_ip, $local_port, $inode);
	
	## HOOK: fillDumps
	## Desc: Use this hook to periodically dump and parse required info from files into an array/hash
	@hooks = L33T_GetHooks("L33Tpacketlog","fillDumps"); foreach (@hooks) { &{$_}; }

	#eth header = 14 bytes, IP header = 20
	$protocol = unpack("C*",substr($pkt, 23, 1));
	$src_ip = unpack("H*",substr($pkt, 29, 1)) .
		unpack("H*",substr($pkt, 28, 1)) .
		unpack("H*",substr($pkt, 27,1)) .
		unpack("H*",substr($pkt, 26, 1));
	$dest_ip = unpack("H*",substr($pkt, 33, 1)) .
		unpack("H*",substr($pkt, 32, 1)) .
		unpack("H*",substr($pkt, 31,1)) .
		unpack("H*",substr($pkt, 30, 1));
	
	#return if transfer is from and to IPs we don't want to track (ie.localhost to localhost)
	return if ($local_ips_tr{$src_ip} && $local_ips_tr{$dest_ip});

	## HOOK: parseAndMatch
	## Desc: Parse the packet based on protocol. Stops calling hooks upon successful match
	## Args: Source IP, Destination IP, Protocol number, reference to entire packet
	## Returns: UID of who transferred packet, local ip, local port, and inode (inode doesn't have to be returned)
	@hooks = L33T_GetHooks("L33Tpacketlog","parseAndMatch");
	foreach (@hooks) {
		($uid, $local_ip, $local_port, $inode) = &{$_}($src_ip, $dest_ip, $protocol, \$pkt);
		last if $uid ne "";
	}
	
	#check if match success
	if ($uid ne "" && $local_ip ne "" && $local_port ne "") {
	
		## HOOK: afterMatch
		## Desc: Correct any of the data that we're about to log
		## Args/Returns: UID, local ip, local port, inode
		@hooks = L33T_GetHooks("L33Tpacketlog","afterMatch");
		foreach (@hooks) {
			($uid, $local_ip, $local_port, $inode) = &{$_}($uid, $local_ip, $local_port, $inode);
		}
		
		#update the log hash
		$log{$uid}{'ip'}{$local_ip}{'port'}{$local_port}{'bytes'} += ${$hdr}{'len'};
	}

	#time to update the log file?
	if (time - $time_log_update > $config_pl{'$log_update_timeout'}) {
		$printTime = int(time);
		open LOG, ">> $config_pl{'$log_file'}";
		L33T_Lock(LOG);
		foreach $user (keys %log) {
			foreach $ip (keys %{$log{$user}{'ip'}}) {
				foreach $port (keys %{$log{$user}{'ip'}{$ip}{'port'}}) {
					$printIP = hex(substr($ip,6,2)).".".hex(substr($ip,4,2)).".".hex(substr($ip,2,2)).".".hex(substr($ip,0,2));
					$printPort = hex($port);
					print LOG "$printTime $user $printIP $printPort $log{$user}{'ip'}{$ip}{'port'}{$port}{'bytes'}\n";
				}
			}
		}
		L33T_Unlock(LOG);
		close LOG;
		undef %log;
		$time_log_update = time;
	}
}

#!/usr/bin/perl
L33T_RegisterHook("L33Tpacketlog","getConfig",\&inode_config);
L33T_RegisterHook("L33Tpacketlog","fillDumps",\&inode_fill);
L33T_RegisterHook("L33Tpacketlog","afterMatch", \&inode_afterMatch);
sub inode_config {
	#TODO: get config from mysql
	$config_pl_inode{'timeout_inode_dump'} = 10;
	$config_pl_inode{'proc'} = "/proc";
	$config_pl_inode{'proc_fd'} = "fd";
	$config_pl_inode{'socketMatch'} = "socket:[";
	$config_pl_inode{'mastered'}{'22'} = 1;
}
sub inode_fill {
	my $qSocketMatch;
	#time to dump?
	if (time - $time_inode_dump > $config_pl_inode{'timeout_inode_dump'}) {
		undef %inode_dump;

		#get all processes
		opendir PROC, $config_pl_inode{'proc'};
		@procs = grep(/^\d+$/, readdir(PROC));
		closedir PROC;
		foreach $proc (@procs) {
			next if !(-d $config_pl_inode{'proc'}."/$proc");
			$uid = (stat($config_pl_inode{'proc'}."/$proc"))[4];

			#get all file descriptors for process
			opendir FD,$config_pl_inode{'proc'}."/$proc/"."$config_pl_inode{'proc_fd'}";
			@fds = grep(/^\d+$/, readdir(FD));
			closedir FD;
			foreach $fd (@fds) {
			
				#look for a socket descriptor
				$qSocketMatch = quotemeta $config_pl_inode{'socketMatch'};
				($inode) = readlink($config_pl_inode{'proc'}."/$proc/"."$config_pl_inode{'proc_fd'}"."/$fd") =~ /^$qSocketMatch(\d+)/;
				if ($inode) {
					$inode_dump{$inode}{'uid'} = $uid;
					$inode_dump{$inode}{'proc'} = $proc;
				}
			}
		}
		$time_inode_dump = time;
	}
}


#We should have the inode from the parseAndMatch hook.  Check to see if this port is 'mastered' (inaccurate UID displayed in /proc/net files)

sub inode_afterMatch {
	my ($uid, $local_ip, $local_port, $inode) = @_;
	if ($config_pl_inode{'mastered'}{hex($local_port)}) {
		$uid = $inode_dump{$inode}{'uid'};
	}
	return ($uid, $local_ip, $local_port, $inode);
}
1;

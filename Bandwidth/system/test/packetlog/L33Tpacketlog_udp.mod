#!/usr/bin/perl
L33T_RegisterHook("L33Tpacketlog","getConfig", \&udp_config);
L33T_RegisterHook("L33Tpacketlog","fillDumps", \&udp_fill);
L33T_RegisterHook("L33Tpacketlog","parseAndMatch",\&upd_parse);

sub udp_config {
	#TODO: get data from mysql
	$config_pl_udp{'timeout_udp_dump'} = 5;
	$config_pl_udp{'proc_net'} = "/proc/net/udp";
}

sub udp_fill {
	my %this;
	my $first;
	#time to dump?
	if (time - $time_udp_dump > $config_pl_udp{'timeout_udp_dump'}) {
		undef @udp_dump;
		$first = 1;
		open NET, $config_pl_udp{'proc_net'};
		foreach (<NET>) {
			if ($first) {
				$first = 0;
				next;
			}
			$this{'src_ip'} = lc(substr($_, 6, 8));
			$this{'src_port'} = lc(substr($_, 15, 4));
			$this{'dest_ip'} = lc(substr($_, 20, 8));
			$this{'dest_port'} = lc(substr($_, 29, 4));
			$this{'uid'} = int(substr($_, 76, 5));
			($this{'inode'}) = substr($_, 91, length($_)-91) =~ /^(\d+)/;
			push @udp_dump, {%this};
	        }
		close NET;
		$time_udp_dump = time;
	}
}

sub upd_parse {
	my ($src_ip, $dest_ip, $protocol, $r_pkt) = @_;
	my ($src_port, $dest_port);
	if ($protocol == 17) {
		$src_port = unpack("H*",substr($$r_pkt, 34, 2));
		$dest_port = unpack("H*",substr($$r_pkt, 36, 2));
		foreach (@udp_dump) {
			#packet could be inbound or outbound, and we don't know which IP (src or dest) is local until after the match (kernel lists local IP first)
			if ((${$_}{'src_ip'} eq $src_ip
				&& ${$_}{'dest_ip'} eq $dest_ip
				&& ${$_}{'src_port'} eq $src_port
				&& ${$_}{'dest_port'} eq $dest_port) ||
				(${$_}{'src_ip'} eq $dest_ip
				&& ${$_}{'dest_ip'} eq $src_ip
				&& ${$_}{'src_port'} eq $dest_port
				&& ${$_}{'dest_port'} eq $src_port)){
				return (${$_}{'uid'}, ${$_}{'src_ip'},${$_}{'src_port'}, ${$_}{'inode'});
			}
		}
	}
}
1;

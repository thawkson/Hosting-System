#!/usr/bin/perl

##################################################################
##								##
##		L33t System Configuration File			##
##								##
##	Most of anything and everything to do with the l33t 	##
##	can be configured in here. System specific variables	##
##	and anything hard coded goes in here.			##
##								##
##################################################################



#########
## L33t system environment variables and constants
#########

$config{'system_absolute_path'} = "/root/L33Tsystem/";
$config{'system_perl_version'} = $];


#########
## L33t's MySQL database configuration stuff
#########

$config{'dbhost'} = "localhost";
$config{'dbport'} = "";
$config{'dbsocket'} = "";

$config{'dbuser_root'} = "root";
$config{'dbpass_root'} = "somepassword";
$config{'dbname_root'} = "mysql";
$config{'dbuser'} = "L33Tadmin";
$config{'dbpass'} = "somepassword";
$config{'dbname'} = "L33Tsystem";


#########
## Bandwidth Daemon constants and config stuff
#########

$config{'bandwidth_http_path'} = "/var/log/httpd/";
$config{'bandwidth_http_regex'} = "/access_log/";
$config{'bandwidth_dbname'} = "L33T_bandwidth"; 
$config{'bandwidth_delay'} = 60;

1;

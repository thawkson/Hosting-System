;Zone File for wicms.com
;
$TTL 3D
@wicms.com                 IN    SOA   wicms.com.    root.wicms.com. (
	                 2008020701     ;Serial
			 8H 	;Refresh
			 2H 	;Retry
			 2W 	;Expire
                         1D 	;Default_ttl
			 )
                         
                         IN 	A 	209.217.82.130
			 IN 	NS 	ns1
			 IN	NS	ns2
			 IN	MX 10	mail.wicms.com.
;*********************
; Routing A Records
;*********************
ns1 		IN 	A 	209.217.82.130
ns2 		IN 	A 	209.217.82.130
mail 		IN 	A 	209.217.82.130
mx1		IN	A	209.217.82.133
mx2		IN	A	209.217.82.133
ftp 		IN 	A 	209.217.82.130
www 		IN 	A 	209.217.82.130
cfmx    	IN      A       209.217.82.130
secure  	IN      A       209.217.82.130
webmin		IN	A	209.217.82.130
webmail		IN	A	209.217.82.130
mike		IN	A	209.217.82.130
gongshow	IN	A	209.217.82.132
mysqldev	IN	A	209.217.82.134

## Installing
On Ubuntu, the following packets are required:

    apt-get install rrdtool librrds-perl libwww-perl sqlite3 nginx

Then add the following to your crontab:

    */1 * * * * /var/www/status.mattrude.com/rrd_nginx.pl

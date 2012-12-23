#!/usr/bin/perl
use RRDs;
use LWP::UserAgent;

# define location of rrdtool databases
my $rrd = '/var/www/status.mattrude.com/rrd';
# define location of images
my $img = '/var/www/status.mattrude.com/images';
# define your nginx stats URL
my $URL = "http://odin.mattrude.com/nginx_status";

my $HOST = "odin";

my $ua = LWP::UserAgent->new(timeout => 30);
my $response = $ua->request(HTTP::Request->new('GET', $URL));

my $requests = 0;
my $total =  0;
my $reading = 0;
my $writing = 0;
my $waiting = 0;

foreach (split(/\n/, $response->content)) {
  $total = $1 if (/^Active connections:\s+(\d+)/);
  if (/^Reading:\s+(\d+).*Writing:\s+(\d+).*Waiting:\s+(\d+)/) {
    $reading = $1;
    $writing = $2;
    $waiting = $3;
  }
  $requests = $3 if (/^\s+(\d+)\s+(\d+)\s+(\d+)/);
}

#print "RQ:$requests; TT:$total; RD:$reading; WR:$writing; WA:$waiting\n";

use DBI;
use strict;

# Connection to DB file created before
#my $dbh = DBI->connect("dbi:SQLite:dbname=nginx.sqlite","","";
my $ERROR = 'test';
my $dbfile = "$rrd/nginx.sqlite";      # your database file
my $dbh = DBI->connect(          # connect to your database, create if
    "dbi:SQLite:dbname=$dbfile", # DSN: dbi, driver, database file
    "",                          # no user
    "",                          # no password
    { RaiseError => 1 },         # complain if something goes wrong
) or die $DBI::errstr;

$dbh->do("insert into `status` (date, request, current, reading, writing, waiting) values (datetime('now'), $requests, $total, $reading, $writing, $waiting)");

# if rrdtool database doesn't exist, create it
if (! -e "$rrd/nginx-$HOST.rrd") {
  RRDs::create "$rrd/nginx-$HOST.rrd",
    "-s 60",
	"DS:requests:COUNTER:90:0:60000",
	"DS:total:ABSOLUTE:90:0:10000",
	"DS:reading:ABSOLUTE:90:0:10000",
	"DS:writing:ABSOLUTE:90:0:10000",
	"DS:waiting:ABSOLUTE:90:0:10000",
	"RRA:AVERAGE:0.5:1:1440",
	"RRA:AVERAGE:0.5:5:288",
	"RRA:AVERAGE:0.5:30:672",
	"RRA:AVERAGE:0.5:120:732",
	"RRA:AVERAGE:0.5:720:1460";
}

# insert values into rrd database
RRDs::update "$rrd/nginx-$HOST.rrd",
  "-t", "requests:total:reading:writing:waiting",
  "N:$requests:$total:$reading:$writing:$waiting";

# Generate graphs
CreateGraphs("hour");
CreateGraphs("day");
CreateGraphs("week");
CreateGraphs("month");
CreateGraphs("year");

#------------------------------------------------------------------------------
sub CreateGraphs($){
  my $period = shift;
  
  RRDs::graph "$img/requests-$HOST-$period.png",
		"-s -1$period",
		"-t HTTP requests on nginx server $HOST.mattrude.com for the last $period",
		"--lazy",
		"-h", "150", "-w", "700",
		"-l 0",
		"-a", "PNG",
		"-v requests/minute",
		"DEF:requests=$rrd/nginx-$HOST.rrd:requests:AVERAGE",
        "CDEF:request=requests,60,*",
		"LINE2:request#336600:Requests",
        "GPRINT:request:LAST:   Current\\: %5.1lf %s",
        "GPRINT:request:MIN:  Min\\: %5.1lf %s",
        "GPRINT:request:AVERAGE: Avg\\: %5.1lf %s",
        "GPRINT:request:MAX:  Max\\: %5.1lf %s\\n",

		"HRULE:0#000000";
  if ($ERROR = RRDs::error) { 
    print "$0: unable to generate $period graph: $ERROR\n"; 
  }

  RRDs::graph "$img/connections-$HOST-$period.png",
		"-s -1$period",
		"-t HTTP requests on nginx server $HOST.mattrude.com for the last $period",
		"--lazy",
		"-h", "150", "-w", "700",
		"-l 0",
		"-a", "PNG",
		"-v requests/minute",
		"DEF:total=$rrd/nginx-$HOST.rrd:total:AVERAGE",
		"DEF:reading=$rrd/nginx-$HOST.rrd:reading:AVERAGE",
		"DEF:writing=$rrd/nginx-$HOST.rrd:writing:AVERAGE",
		"DEF:waiting=$rrd/nginx-$HOST.rrd:waiting:AVERAGE",
        "CDEF:totals=total,60,*",
        "CDEF:readings=reading,60,*",
        "CDEF:writings=writing,60,*",
        "CDEF:waitings=waiting,60,*",

		"LINE2:totals#336600:Total",
		"GPRINT:totals:LAST:   Current\\: %5.1lf %S",
		"GPRINT:totals:MIN:  Min\\: %5.1lf %S",
		"GPRINT:totals:AVERAGE: Avg\\: %5.1lf %S",
		"GPRINT:totals:MAX:  Max\\: %5.1lf %S\\n",
		
		"LINE2:readings#0022FF:Reading",
		"GPRINT:readings:LAST: Current\\: %5.1lf %S",
		"GPRINT:readings:MIN:  Min\\: %5.1lf %S",
		"GPRINT:readings:AVERAGE: Avg\\: %5.1lf %S",
		"GPRINT:readings:MAX:  Max\\: %5.1lf %S\\n",
		
		"LINE2:writings#FF0000:Writing",
		"GPRINT:writings:LAST: Current\\: %5.1lf %S",
		"GPRINT:writings:MIN:  Min\\: %5.1lf %S",
		"GPRINT:writings:AVERAGE: Avg\\: %5.1lf %S",
		"GPRINT:writings:MAX:  Max\\: %5.1lf %S\\n",
		
		"LINE2:waitings#00AAAA:Waiting",
		"GPRINT:waitings:LAST: Current\\: %5.1lf %S",
		"GPRINT:waitings:MIN:  Min\\: %5.1lf %S",
		"GPRINT:waitings:AVERAGE: Avg\\: %5.1lf %S",
		"GPRINT:waitings:MAX:  Max\\: %5.1lf %S\\n",

		"HRULE:0#000000";
  if ($ERROR = RRDs::error) { 
    print "$0: unable to generate $period graph: $ERROR\n"; 
  }
}

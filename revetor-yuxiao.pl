#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use FindBin;
use lib '/var/www/html/cmsShowWeb'; 


use RevetorCommon;

my $q = CGI->new;

my $buf =
    connect_to_server(
        qq{{"action": "report_usage"}\n},
        0
    );


if (defined $buf && $buf =~ /(\d+).*?(\d+)/)
{
  chomp($buf);
  $buf =~ s/\r//g;
  $buf =~ s/\0//g;
   my $mark = "";
     
	$mark = "Status: currently serving $2 total $1";


    print $q->header('text/html');

    my $file = "/var/www/html/cmsShowWeb/ui5-common-gateway.html";

   open(my $fh, '<', $file)
    or die "Cannot open $file: $!";

   local $/;
   my $html = <$fh>;
   close($fh);

   $html =~ s/MARK/$mark/g;
   my $xx =  $ENV{'HTTP_HOST'};
   $html =~ s/MACHINE/$xx/g;
   # CERN SSO login name (mod_auth_openidc claim)
   my $CERN_UPN = $ENV{'OIDC_CLAIM_cern_upn'} // 'there';
   $html =~ s/TestUser/$CERN_UPN/g;

   print $html;
}
else
{

    print "Content-Type: text/html\n\n";

    print <<'EOF';
<!DOCTYPE html>
<html>
<head>
    <title>cmsShowWeb Backend Unavailable</title>
</head>
<body style="font-family: Arial; text-align: center; margin-top: 50px;">
    <h1 style="color: red;">cmsShowWeb Backend Unavailable</h1>

    <p>
        The cmsShowWeb backend service is currently unavailable.
    </p>

    <p>
        Please report the problem in the CMS HyperNews Visualization forum:
    </p>

    <p>
        <a href="https://cms-talk.web.cern.ch/c/offcomp/visualization/165">
            CMS Visualization Discussion Forum
        </a>
    </p>
</body>
</html>
EOF
}

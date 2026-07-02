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

chomp($buf);
$buf =~ s/\r//g;
$buf =~ s/\0//g;

my $mark = "";

if ($buf =~ /(\d+).*?(\d+)/)
{
    $mark = "Status: currently serving $2 total $1";
}

print $q->header('text/html');

my $file = "/var/www/html/cmsShowWeb/ui5-gateway.html";

open(my $fh, '<', $file)
    or die "Cannot open $file: $!";

local $/;
my $html = <$fh>;
close($fh);

$html =~ s/MARK/$mark/g;
my $xx =  $ENV{'HTTP_HOST'};
$html =~ s/MACHINE/$xx/g;

print $html;


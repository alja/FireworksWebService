package RevetorCommon;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw(
    cgi_print
    cgi_die
    cgi_end
    flush
    recv_with_timeout
    connect_to_server
);

use IO::Socket::INET;
use IO::Socket::Timeout;

our $EVE_HOST = 'localhost';
our $EVE_PORT = 6666;

############################################################
# CGI helpers
############################################################

sub cgi_print {
    print "<p><pre>", join("\n", @_), "</pre>\n";
}

sub cgi_end {
    print <<"EOF";

</body>
</html>
EOF
}

sub cgi_die {
    print "<p><b> $_[0] </b>\n";
    cgi_end();
    exit(1);
}

sub flush {
    select()->flush();
}

############################################################
# Socket receive with timeout (FIXED)
############################################################

sub recv_with_timeout {
    my ($sock, $size, $timeout, $err_to) = @_;
    $timeout ||= 5;
    $err_to  ||= 100;

    $sock->read_timeout($timeout);

    my $buf = '';
    my $sum_t = 0;

    while (1) {

        my $tmp;
        my $ret = $sock->recv($tmp, $size);

        # success with data
        if (defined $ret && length($tmp)) {
            $buf = $tmp;
            last;
        }

        $sum_t += $timeout;

        warn "Waiting for server response (${sum_t}s / ${err_to}s)\n";

        return undef if $sum_t >= $err_to;
    }

    chomp $buf;
    return $buf;
}

############################################################
# Connect to backend server
############################################################

sub connect_to_server {
    my ($request, $verbose) = @_;

    cgi_print("Connecting to cmsShowWeb backend...") if $verbose;

    my $client = IO::Socket::INET->new(
        PeerHost => $EVE_HOST,
        PeerPort => $EVE_PORT,
        Proto    => 'tcp',
        Type     => SOCK_STREAM,
        Timeout  => 5,
    ) || cgi_die("Can't open socket: $@");

    IO::Socket::Timeout->enable_timeouts_on($client);

    cgi_print("Connected to port $EVE_PORT") if $verbose;

    my $buf = recv_with_timeout($client, 1024, 5, 30);

    unless (defined $buf && length($buf)) {
        my $err = $!;
        cgi_print("Error receiving server greeting: $err");
        $client->close();
        return '';
    }

    cgi_print("Server greeting: $buf") if $verbose;

    cgi_print("Sending request...") if $verbose;

    my $size = $client->send($request);
    unless ($size) {
        cgi_die("Failed to send request: $!");
    }

    cgi_print("Sent $size bytes") if $verbose;

    flush();

    $buf = recv_with_timeout($client, 1024, 5, 300);

    if (defined $buf && length($buf)) {
        cgi_print("Server response received") if $verbose;
    } else {
        cgi_print("Error receiving server response: $!");
    }

    $client->close();

    return $buf;
}

1;

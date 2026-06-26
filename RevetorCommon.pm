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

use IO::Socket qw(AF_INET SOCK_STREAM);
use IO::Socket::Timeout;

our $EVE_HOST = 'localhost';
our $EVE_PORT = 6666;

sub cgi_print
{
    print "<p><pre>", join("\n", @_), "</pre>\n";
}

sub cgi_end
{
    print <<"EOF";

</body>
</html>
EOF
}

sub cgi_die
{
    print "<p><b> $_[0] </b>\n";
    cgi_end();
    exit(1);
}

sub flush
{
    select()->flush();
}

sub recv_with_timeout
{
    my $sock    = shift;
    my $size    = shift;
    my $timeout = shift || 5;
    my $err_to  = shift || 100;

    my $buf;
    my $sum_t = 0;

    $sock->read_timeout($timeout);

    my $ret;
    while (not defined ($ret = $sock->recv($buf, $size)))
    {
        $sum_t += $timeout;

        cgi_print(
            "Waiting for server response, ${sum_t}s [ max = ${err_to}s ]"
        );

        flush();

        return undef if $sum_t >= $err_to;
    }

    chomp $buf;
    return $buf;
}

sub connect_to_server
{
    my ($request, $verbose) = @_;

    cgi_print("Connecting to local cmsShowWeb forker now ...")
        if $verbose;

    my $client = IO::Socket->new(
        Domain   => AF_INET,
        Type     => SOCK_STREAM,
        proto    => 'tcp',
        PeerHost => $EVE_HOST,
        PeerPort => $EVE_PORT,
        Timeout  => 5
    ) || cgi_die("Can't open socket: $@");

    IO::Socket::Timeout->enable_timeouts_on($client);

    cgi_print("Connected to $EVE_PORT")
        if $verbose;

    my $buf = recv_with_timeout($client, 1024, 5, 30);

    unless (length($buf))
    {
        my $err = $!;
        cgi_print("Error receiving server greeting, error: $err.");
        $client->close();
        return $buf;
    }

    cgi_print("Server greeting: $buf")
        if $verbose;

    cgi_print("Sending $request")
        if $verbose;

    my $size = $client->send($request);

    cgi_print("Sent data of length: $size")
        if $verbose;

    flush();

    $buf = recv_with_timeout($client, 1024, 5, 300);

    if (length($buf))
    {
        cgi_print("Server response: $buf")
            if $verbose;
    }
    else
    {
        my $err = $!;
        cgi_print("Error receiving server response, error: $err.");
    }

    $client->close();

    return $buf;
}

1;


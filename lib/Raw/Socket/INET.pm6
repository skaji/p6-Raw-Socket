use v6;

use Raw::Socket;

use NativeCall;

use LibraryMake;

sub library {
    my $so = get-vars('')<SO>;
    my $libname = "Raw/Socket/libsocket$so";
    for @*INC <-> $inc {
        if $inc ~~ Str {
            $inc ~~ s/^.*\#//;
            return "$inc/$libname" if "$inc/$libname".IO.r;
        }
    }
    die "Unable to find library: $libname";
}

# moarvm rewrites errno.
sub p6_socket_new()
    returns OpaquePointer
    is native(&library) { ... }

sub p6_socket_free(OpaquePointer)
    is native(&library) { ... }

sub p6_socket_strerror(OpaquePointer)
    returns Str
    is native(&library) { ... }

sub p6_socket_inet_socket(OpaquePointer)
    returns Int
    is native(&library) { ... }

sub p6_socket_set_so_reuseaddr(OpaquePointer, Int $n)
    returns Int
    is native(&library) { ... }

sub p6_socket_inet_bind(OpaquePointer, Str $host, int $port)
    returns int
    is native(&library) { ... }

sub p6_socket_listen(OpaquePointer, int $backlog)
    returns int
    is native(&library) { ... }

sub p6_socket_accept(OpaquePointer, OpaquePointer)
    returns int
    is native(&library) { ... }

sub p6_socket_recv(OpaquePointer, Buf, int, int)
    returns int
    is native(&library) { ... }

sub p6_socket_send(OpaquePointer, Buf, int, int)
    returns int
    is native(&library) { ... }

sub p6_socket_close(OpaquePointer)
    returns int
    is native(&library) { ... }

class Raw::Socket::INET {
    has OpaquePointer $!sock;

    has Int $.listen;
    has Str $.localhost = '0.0.0.0';
    has int $.localport;
    has Bool $.reuseaddr = True;

    method new(*%args is copy) {
        fail "Nothing given for new socket to connect or bind to" unless %args<host> || %args<listen>;

        fail "client socket does not supported yet" unless %args<listen>;
        self.bless(|%args)!initialize()
    }

    submethod DESTROY() {
        if ($!sock) {
            say 'freeing socket';
            p6_socket_free($!sock);
        }
    }

    method !initialize() {
        $!sock = p6_socket_new();
        if (!$!sock) {
            die "cannot allocate memory";
        }
        if (p6_socket_inet_socket($!sock) < 0) {
            die "cannot open socket: {self!error}";
        }
        if ($.reuseaddr) {
            if (p6_socket_set_so_reuseaddr($!sock, 1) < 0) {
                die "cannot set SO_REUSEADDR: {self!error}";
            }
        }
        my $s = p6_socket_inet_bind($!sock, $.localhost, $.localport);
        if ($s != 0) {
            die "cannot bind $.localhost:$.localport: {self!error}";
        }
        if (p6_socket_listen($!sock, $.listen) < 0) {
            die "cannot listen: {self!error}";
        }
        return self;
    }

    method accept() {
        my $csock = p6_socket_new();
        if (!$csock) {
            die "cannot allocate memory";
        }
        if (p6_socket_accept($!sock, $csock) < 0) {
            p6_socket_free($csock);
            die "cannot accept: {self!error}";
        } else {
            return $?CLASS.bless()!init-by-socket($csock);
        }
    }

    method !init-by-socket($csock) {
        $!sock = $csock;
        return self;
    }

    method recv(Buf $buf, int64 $len, int $flags) {
        my $s = p6_socket_recv($!sock, $buf, $buf.elems, $flags);
        if ($s < 0) {
            die "cannot recv: {self!error}";
        }
        return $s;
    }

    method send(Blob $buf, int $flags) {
        my $s = p6_socket_send($!sock, $buf, $buf.elems, $flags);
        if ($s < 0) {
            die "cannot send: {self!error}";
        }
        return $s;
    }

    method close() {
        return p6_socket_close($!sock);
    }

    method !error() {
        return p6_socket_strerror($!sock);
    }
}

package Config::Simple;
# $Id: Simple.pm,v 3.0 2002/11/03 02:59:22 sherzodr Exp $

use strict;
use Carp 'croak';
use Fcntl (':DEFAULT', ':flock');

use vars qw($VERSION);

($VERSION) = '$Revision: 3.0 $' =~ m/Revision:\s*(\S+)/;


sub new {
    my $class = shift;
    $class = ref($class) || $class;

    my $self = {
        _options => {
            encoder => sub { my($string)=@_; $string=~s/\n/\\n/g; return $string },
            decoder => sub { my($string)=@_; $string=~s/\\n/\n/g; return $string },
            autosave => 0,
            filename => 0,
        },
        _data    => { },

    };

    # If there's only one argument, consider it's the filename
    if ( @_ == 1 ) {
        $self->{_options}->{filename} = $_[0];

    } else {
        # if there're more than one arguments, consider them as key/value pairs
        $self->{_options} = {
            encoder => sub { my($string)=@_; $string=~s/\n/\\n/g; return $string },
            decoder => sub { my($string)=@_; $string=~s/\\n/\n/g; return $string },
            autosave => 0,
            filename => 0,
            @_, };
    }

    bless($self, $class);

    if ( $self->{_options}->{filename} ) {
        $self->read();
    }
    return $self;
}



sub DESTROY {
    my $self = shift;

    if ( $self->{_options}->{autosave} ) {
        $self->write();
    }

    if ( defined $self->{_fh} ) {
        my $fh = $self->{_fh};
        unless ( close ( $fh ) ) {
            croak "Couldn't close $self->{_options}->{filename}: $!";
        }
    }
}





sub read {
    my ($self, $arg) = @_;

    if ( defined $arg ) {
        $self->{_options}->{filename} = $arg;
    }

    my $filename = $self->{_options}->{filename};

    unless ( sysopen(CFG, $filename, O_RDWR|O_CREAT) ) {
        croak "Couldn't read $filename: $!";
    }
    $self->{_fh} = \*CFG;
    unless ( flock(CFG, LOCK_SH) ) {
        croak "Couldn't LOCK_SH $filename: $!";
    }

    # whitespace support (\s*) added by Michael Caldwell <mjc@mjcnet.com>
    # date: Tuesday, May 14, 2002
    my ($blockname, $afterdot);
    while ( <CFG> ) {
        $afterdot                   and $self->{_after_dot} .= $_, next;
        /^(\n|\#|;)/                and next;
        /\s*\[([^\]]+)\]\s*/        and $blockname = lc($1), next;
        /\s*([^=]+?)\s*=\s*(.+)/    and $self->{_data}->{$blockname}->{lc($1)}=$self->_decode($2), next;
        /^\./                       and $afterdot=1, next;

        # If we came this far, something smells fishy around here
        croak "Syntax error on line $.:'$_'";
    }

    unless ( flock(CFG, LOCK_UN) ) {
        croak "Couldn't LOCK_UN $filename: $!";
    }
}







sub _get_block {
    my ($self, $blockname) = @_;
    return $self->{_data}->{$blockname};
}








sub _get_param {
    my ($self, $blockname, $param) = @_;

    # if $param doesn't exist, treat $blockname as $blockname.$param
    unless ( defined $param ) {
        ($blockname, $param) = split(/\./, $blockname);
    }

    unless ( defined $param ) {
        croak "_get_param(): RTFM!";
    }

    return $self->{_data}->{$blockname}->{$param};
}









sub _set_param {
    my ($self, $blockname, $param, $value) = @_;

    if ( @_ < 3 ) {
        croak "_set_param(): RTFM!";
    }

    # if the last argument, value is missing, treat $param as $value,
    # and treat $blockanme as $blockname.$param
    unless ( $value ) {
        $value = $param;
        ($blockname, $param) = split (/\./, $blockname);
    }

    unless ( $blockname ) {
        croak "_set_param(): RTFM!";
    }

    $self->{_data}->{lc($blockname)}->{lc($param)} = $value;
}










sub _set_block {
    my ($self, $blockname, $block) = @_;

    unless ( defined $block ) {
        croak "Block contents are missing";
    }

    unless ( ref($block) eq 'HASH' ) {
        croak "Block contents should be hash reference";
    }

    $self->{_data}->{lc($blockname)} = $block;
}




sub hashref {
    my $self = shift;

    my $data = $self->{_data};

    my %Hash = ();
    while ( my ($blockname, $block) = each %{$data} ) {
        while ( my ($key, $value) = each %{$block} ) {
            $Hash{ "$blockname.$key" } = $value;
        }
    }
    return \%Hash;
}


sub param_hash {
    my $self = shift;

    return %{ $self->hashref() };
}


sub param {
    my $self  = shift;

    # if called without any arguments, returns all the
    # available keys
    unless ( @_ ) {
        return keys %{ $self->hashref };
    }

    # if called with a single argument, returns a matching value
    if ( @_ == 1 ) {
        # consider it as blockname.param
        return $self->_get_param( $_[0] );
    }

    # If we're this far, we have to figure out which of the following
    # syntax are used:
    # param(-name=>'block.param'), param('block.name', 'value'),
    # param(-name=>'block.param', -value=>'value'), param(-block=>'block')
    my $args = {
        '-name'     => undef,
        '-value'    => undef,
        '-values'   => undef,
        '-block'    => undef,
        @_,
    };

    if ( $args->{'-name'} && $args->{'-value'} ) {
        return $self->_set_param($args->{'-name'}, $args->{'-value'});
    }

    if ( $args->{'-name'} ) {
        return $self->_get_param($args->{'-name'});
    }

    if ( $args->{'-block'} && $args->{'-values'} ) {
        return $self->_set_block($args->{'-block'}, $args->{'-values'});
    }

    if ( $args->{'-block'} ) {
        return $self->_get_block($args->{'-block'});
    }

    # if we came this far, most likely simple param(key=>value) syntax was used:
    if ( @_ == 2 ) {
        return $self->_set_param(@_);
    }

    croak "Config::Simple->param() usage was incorrect!";
}



sub write {
    my ($self, $new_file) = @_;

    my $data    = $self->{_data}    or return;
    my $fh      = $self->{_fh}      or return;
    my $file    = $self->{_options}->{filename};

    if ( defined $new_file ) {
        unless ( sysopen (NEWFILE, $new_file, O_WRONLY|O_CREAT|O_TRUNC, 0666) ) {
            croak "Couldn't open $new_file: $!";
        }
        $fh = \*NEWFILE;
    }

    unless ( flock ($fh, LOCK_EX) ) {
        croak "Couldn't LOCK_EX $file: $!";
    }

    unless ( truncate($fh, 0) ) {
        croak "Couldn't truncate $file: $!";
    }

    unless ( seek($fh, 0, 0) ) {
        croak "Couldn't seek to the start of the file: $!";
    }

    print $fh "; Maintained by Config::Simple/$VERSION\n";
    print $fh '; ', "-" x 35, "\n\n\n";

    while ( my ($blockname, $block) = each %{$data} ) {
        print $fh "[$blockname]\n";
        while ( my ($key, $value) = each %{$block} ) {
            $value = $self->_encode($value);
            print $fh "$key=$value\n";
        }
        print $fh "\n\n";
    }

    if ( $self->{_after_dot} ) {
        print $fh ".\n", $self->{_after_dot};
    }

    unless ( flock($fh, LOCK_UN) ) {
        croak "Couldn't unlock $file: $!";
    }

    if ( defined $new_file ) {
        unless ( close($fh) ) {
            croak "Couldn't close $new_file: $!";
        }
    }
}


sub _encode {
    my ($self, $string) = @_;
    return $self->{_options}->{encoder}->($string);
}



sub _decode {
    my ($self, $string) = @_;

    return $self->{_options}->{decoder}->($string);
}

sub dump {
    my ($self, $file) = @_;

    require Data::Dumper;
    my $d = new Data::Dumper([$self], ["obj_tree"]);

    if ( defined $file ) {
        unless ( sysopen(DUMP_FILE, $file, O_WRONLY|O_CREAT|O_TRUNC, 0666 ) ) {
            croak "Couldn't dump into $file: $!";
        }
        unless ( flock(DUMP_FILE, LOCK_SH) ) {
            croak "Couldn't LOCK_SH $file: $!";
        }
        print DUMP_FILE $d->Dump();
        unless ( close (DUMP_FILE) ) {
            croak "Couldn't close $file: $!";
        }
    }
    return $d->Dump();
}


sub autosave {
    my ($self, $new_value) = @_;

    unless ( defined $new_value ) {
        return $self->{_options}->{autosave} || 0;
    }

    $self->{_options}->{autosave} = $new_value;
}



sub version {

    return $VERSION;
}


sub encoder {
    my ($self, $coderef) = @_;

    unless ( ref($coderef) eq 'CODE' ) {
        croak "set_encoder(): should've set coderef";
    }

    $self->{_options}->{encoder} = $coderef;
}


sub decoder {
    my ($self, $coderef) = @_;

    unless ( ref($coderef) eq 'CODE' ) {
        croak "set_encoder(): should've set coderef";
    }

    $self->{_options}->{decoder} = $coderef;
}

1;

=pod

=head1 NAME

Config::Simple - Simple Configuration File class

=head1 SYNOPSIS


    # In your configuratin file (some.cfg)
    [mysql]
    user=sherzodr
    password=secret
    host=localhost
    database=test




    # In your program

    use Config::Simple;

    my $cfg = new Config::Simple("some.cfg");

    # reading
    my $user = $cfg->param('mysql.user');
    my $password = $cfg->param('mysql.password');

    # updating
    $cfg->param('mysql.user', foo);

    # saving the changes back into the file
    $cfg->write();

    # tricks are endless


=head1 DESCRIPTION

Config::Simple is a Perl class to manipulate simple, windows-ini-styled
configuration files. Reading and writing external configurable data is
the integral part of any software design, and Config::Simple is designed to
help you with it.

=head1 REVISION

This manual refers to $Revision: 3.0 $

=head1 CONSTRUCTOR

C<new()> - constructor,  initializes and returns Config::Simple object. Following
options are available:

=over 4

=item *

C<filename> - filename to read into memory. If this option is defined,
Config::Simple also calls read() for you. If there's only one argument
passed to the constructor, it will be treated as the filename as well.

=item *

C<autosave> - boolean value indicating if in-memory modifications be saved back
to configuration file before object is destroyed. Default is 0, which means "no".
(See L<autosave()>)

=item *

C<decoder> - reference to a function (coderef), is used by read() to decode the
values. If this option is missing, default decoder will be used,
which simply decodes new line characters (\n) back to newlines (opposite of default
encoder). See L<decoder()>.

=item *

C<encoder> - reference to a function (coderef). Is used by write() to encode
special characters/sequences before saving them in the configuration file.
If this option is missing, default encoder will be used, which encodes newlines to avoid
corrupted configuration files. See L<encoder()>.

=back

All the arguments to the constructor can also be set with their respective accessor methods.
However, there's an important point to keep in mind. If you define filename as an argument
while calling the constructor and at the same time want to use your custom decoder, you should specify
the decoder together with the filename. Otherwise, when constructor calls read(), it will
use default decoder(). Another option is not to mention filename to constructor, but do so
to read().

=head1 METHODS

Following methods are available for a Config::Simple object

=over 4

=item *

read() - reads and parses the configuration file into Config::Simple object. Accepts one argument,
which is treated as a filename to read. If "filename" option to the constructor was defined,
there's no point calling read(), since new() will call it for you.
Example:

    $cfg = new Config::Simple();
    $cfg->read("some.cfg");

=item *

hashref() - returns the configuration file as a reference to a hash. Keys consist of
configuration section and section key separated by a dot (.), and value holding the value
for that key. Example:

    # some.cfg
    [section]
    key1=value1
    key2=value2

Hashref will return the following hash:

    $ref = {
        'section.key1' => value1,
        'section.key2' => value2,
    }

=item *

param_hash() - for backward compatibility. Returns similar data as hashref() does
(see L<hashref()>), but returns de referenced hash.

=item *

param() - used for accessing and modifying configuration values. Act differently
depending on the arguments passed.

=over 4

=item param()

If used with no arguments, returns all the
keys available in the configuration file. Once again, keys are sections and section
variables delimited with a dot.

=item param($key)

If used with a single argument, returns the respective value for that key. Argument
is expected to be in the form of "sectionName.variableName".

=item param(-name=>$key)

The same as the previous syntax.

=item param($key, $value)

Used to modify $key with $value. $key is expected to be in "sectionName.variableName" format.

=item param(-name=>$key, -value=>$value);

The same as the previous syntax.

=item param(-block=>$blockname)

Returns a single block/section from the configuration file in form of hashref (reference to
a hash). For example, assume we had the following block in our "some.cfg"

    [mysql]
    user=sherzodr
    password=secret
    host=localhost
    database=test

We can access the above block like so:

    my $mysql = $cfg->param(-block=>'mysql');
    my $user = $mysql->{user};
    my $host = $mysql->{host};

=item param(-block=>$blockname, -values=>{key1 => value1,...})

Used to create a new block or redefine the existing one.


=back

=item *

write() - saves the modifications to the configuration file. Config::Simple
will call write() for you automatically if 'autosave' was set to true (see L<new()>). Otherwise,
write() is there for you if need. Argument, if exists, will be treated a name of a file
current data should be written in. It's useful to copy modified configuration file
to a different location, or to save the backup copy of a current configuration file
before making any changes to it:

    $cfg = new Config::Simple(filename=>'some.cfg', autosave=>1);

    $cfg->write('some.cfg.bak');        # creating backup copy
                                        # before updating the contents

=item *

encoder() - sets a new encoder to be used in the form of coderef. This encoder
will be used by write() before writing the values back to a file. Alternatively,
you can define the encoder as an argument to constructor ( see L<new()> ).

=item *

decoder() - sets a new decoder to be used in the form of coderef. This decoder is
used by read() ( see L<read()> ), so should be set (if at all) before calling read().
Alternatively, you can define the decoder as an argument to constructor ( see L<new()> ).

=item *

autosave() - sets autosave value (see L<new()>)


=item *

dump() - dumps the object data structure either to STDOUT or into a filename which
can be defined as the first argument. Used for debugging only

=back

=head1 CREDITS

Following people contributed with patches and/or suggestions to the Config::Simple.
In chronological order:

=over 4

=item Michael Caldwell (mjc@mjcnet.com)

Added witespace support in the configuration files, which enables custom identation

=item Scott Weinstein (Scott.Weinstein@lazard.com)

Fixed the bugs in the TIEHASH method.

=back

=head1 AUTHOR

Config::Simple is written and maintained by Sherzod Ruzmetov <sherzodr@cpan.org>

=head1 COPYRIGHT

    This library is a free software, and can be modified and redistributed
    under the same terms as Perl itself.

=head1 SEE ALSO

L<Config::General>

=cut

package Config::Config;

use 5.006;
use strict;
use FileHandle;
use Carp;

our $VERSION = '0.01';

sub new {
    my $class = shift;
    $class = ref ($class) || $class;

    my $self = {
        _filename => '',
        @_,
    };

    my $fh = new FileHandle $self->{_filename}, O_RDONLY;

    unless (defined $fh) {
        croak "$self->{filename} couldn't be opened in O_RDONLY mode: $!";
    }

    my $section;
    while ( <$fh> ) {
        m/^(#|\n)/ && next;
        chomp;
        /^\[(.+)\]/ && ($section = $1);
        /^([^=]+)=([^=]+)/ && ($self->{"$section.$1"} = $2);
    }

    undef $fh;

    bless $self, $class;

    return $self;
}





sub param {
    my ($self, $key) = @_;

    if ($key) { return $self->{$key}    }

    my @param;
    map { /^[^_]/ && push @param, $_} keys %{$self};
    return @param;
}


sub set_param {
    my ($self, $key, $value) = @_;

    $self->{$key} = $value;
}




sub write {
    my ($self, $file) = @_;

    $file ||=$self->{_filename};

    my ($section, $key, %Cfg);
    for ( sort keys %{$self} ) {
        if (/^([^\.]+)\.([^\.]+)/) {
            $section="[$1]\n", $key=$2;
            $Cfg{$section}.="$key=$self->{$_}\n";
        }
    }


    my $fh = new FileHandle $file, O_CREAT|O_WRONLY;
    unless (defined $fh) {
        croak "file $file couldn't be opened in O_CREAT|O_WRONLY mode: $!";
    }


    print $fh %Cfg;


    undef $fh;
}





sub dump {
    my $self = shift;
    require Data::Dumper;

    print Data::Dumper::Dumper($self);

}






1;
__END__
# Below is stub documentation for the class.

=head1 NAME

Config::Simple - Perl extension for reading and writing configuration files

=head1 SYNOPSIS

  use Config::Simple;
  my $cfg = new Config::Simple(_filename=>'/home/sherzodr/lib/Poll.cfg');
  print "Your mysql password is: ", $cfg->param('mysql.password'), "\n";
  print "Your mysql login is: ", $cfg->param('mysql.login'), "\n";

  # modifying parameters:

  $cfg->set_param('mysql.password', 'new_password');

  print "Now your new password is ", $cfg->param("mysql.password"), "\n";

  # now writing all the modifications back to the configuration file:

  $cfg->write;

  # now creating a copy of the configuration file, instead of
  # writing it back to the same file:

  $cfg->write('new_file.cfg.bk');

=head1 DESCRIPTION

Config::Simple is used for reading and writing configuration files in the following format:

    [mysql]
    host=ultracgis.com
    login=sherzodr
    password=secret

    [site]
    admin=Sherzod B. Ruzmetov
    admin_email=sherzodr@cpan.org
    url=http://www.ultracgis.com


You could also use this module to creat brand new configuration files.
If the file you pass to C<new()> does not exist, it will create the file.
If you want to create the section called '[author]' in the configuration file
with two attributes, 'first name' and 'last name', the following trick would work:

    my $cfg = new Config::Simple(_filename=>'MyConfig.cfg');
    $cfg->set_param('author.first name', 'Sherzod');
    $cfg->set_param('author.last name', 'Ruzmetov');

    $cfg->write;

MyConfig.cfg file looks like the following:

    [author]
    first name=Sherzod
    last name=Ruzmetov

If you want to get all the attributes in the configuration file, just call
param() method with no arguments.

    my @attr = $cfg->param;

Now @attr array consists of all the attributes available in the configuration file.
If we use the following piece of code

    print join "\n", $cfg->param;

to the bove create MyConfig.cfg file, the result would look like the following:

    author.first name
    author.last name


Enjoy!

=head1 AUTHOR

Sherzod Ruzmetov <sherzodr@cpan.org>

=head1 SEE ALSO



=cut

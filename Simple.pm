package Config::Simple;

# $Id: Simple.pm,v 3.14 2003/02/20 10:56:27 sherzodr Exp $

use strict;
use Carp;
use Text::ParseWords 'parse_line';
use vars qw($VERSION $DEFAULTNS $LC);

($VERSION) = '$Revision: 3.14 $' =~ m/Revision:\s*(\S+)/;
$DEFAULTNS = 'default';

sub import {
  for ( @_ ) {
    $LC = ($_ eq '-lc')     and next;
  }
}


# fcntl constants
sub O_APPEND   () { return 1024   }
sub O_CREAT    () { return 64     }
sub O_EXCL     () { return 128    }
sub O_RDWR     () { return 2      }
sub O_TRUNC    () { return 512    }
sub O_WRONLY   () { return 1      }
sub LOCK_EX    () { return 2      }
sub LOCK_SH    () { return 1      }
sub LOCK_UN    () { return 8      }

sub DELIM      () { return '\s*,\s*' }
sub DEBUG      () { 0 }


sub new {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
    _FILE_HANDLE    => undef,
    _FILE_NAME      => undef,
    _STACK          => [],
    _DATA           => {},
    _SYNTAX         => undef,
    _SUB_SYNTAX     => undef,
    _ARGS           => {}
  };


  bless ($self, $class);
  $self->_init(@_);

  return $self;
}




sub DESTROY {
  my $self = shift;

  if ( $self->autosave() ) {
    $self->write();
  }
}




sub _init {
  my $self = shift;

  if ( @_ == 1 ) {
    return $self->read($_[0]);

  } elsif ( @_ % 2 ) {
    croak "new(): Illegal arguments detected";

  } else {
    $self->{_ARGS} = { @_ };

  }

  if ( exists ($self->{_ARGS}->{filename}) ) {
    return $self->read( $self->{_ARGS}->{filename} );
  }
}



sub autosave {
  my ($self, $bool) = @_;

  if ( defined $bool ) {
    $self->{_ARGS}->{autosave} = $bool;
  }

  return $self->{_ARGS}->{autosave};
}




sub read {
  my ($self, $file) = @_;

  if ( defined $self->{_FH} ) {
    croak "Opened file handle detected. If you're trying to parse another file, close it first.";
  }

  unless ( $file ) {
    croak "Usage: OBJ->read(\$file_name)";
  }

  unless ( sysopen(FH, $file, O_RDWR|O_CREAT, 0600  ) ) {
    croak "Couldn't read '$file': $!";
  }

  $self->{_FILE_NAME}   = $file;
  $self->{_FILE_HANDLE} = \*FH;
  $self->{_SYNTAX} = $self->guess_syntax();

  $self->{_SYNTAX} eq 'ini'     and $self->parse_ini_file();
  $self->{_SYNTAX} eq 'simple'  and $self->parse_cfg_file();
  $self->{_SYNTAX} eq 'http'    and $self->parse_http_file();
}



# tries to guess the syntax of the configuration file.
# returns 'ini', 'simple' or 'http'.
sub guess_syntax {
  my ($self, $fh) = @_;

  unless ( defined $fh ) {
    $fh = $self->{_FILE_HANDLE} or die "'_FILE_HANDLE' is not defined";
  }

  seek($fh, 0, 0) or croak "Couldn't seek($fh, 0, 0): $!";

  # now we keep reading the file line by line untill we can identify the
  # syntax
  verbose("Trying to guess the file syntax...");
  while ( <$fh> ) {
    # skipping emptpy lines and comments. They don't tell much anyways
    /^(\n|\#|;)/ and next;
    /\w/ or next;

    chomp();

    # If there's a block, it is an ini syntax
    /^\s*\[\s*[^\]]+\s*\]\s*$/  and verbose("'$_'-ini style"), return 'ini';

    # If we can read key/value pairs seperated by '=', it still
    # is an ini syntax with a default block assumed
    /^\s*[^=]+\s*=\s*.*\s*$/    and $self->{_SUB_SYNTAX} = 'simple-ini', return 'ini';

    # If we can read key/value pairs seperated by ':', it is an
    # http syntax
    /^\s*[\w-]+\s*:\s*.*\s*$/   and return 'http';

    # If we can read key/value pairs seperated by just whitespase,
    # it is a simple syntax.
    /^\s*[\w-]+\s+.*$/          and return 'simple';

    # If we came this far, we're still struggling to figure
    # out the syntax. Just throw an exception:
    croak "Couldn't guess file syntax";
  }
}







sub parse_ini_file {
  my ($self, $fh) = @_;

  unless ( defined $fh ) {
    $fh = $self->{_FILE_HANDLE} or die "'_FILE_HANDLE' is not defined";
  }

  seek($fh, 0, 0) or croak "Couldn't seek($fh, 0, 0) in '$self->{_FILE_NAME}': $!";

  my $bn = $DEFAULTNS;
  my %data = ();
  while ( <$fh> ) {
    # skipping comments and empty lines:
    /^(\n|\#|;)/  and next;
    /\w/          or  next;

    # stripping $/:
    chomp();

    # parsing the blockname:
    /^\s*\[\s*([^\]]+)\s*\]$/       and $bn = lcase($1), next;

    # parsing key/value pairs
    /^\s*([^=]*\w)\s*=\s*(.*)\s*$/  and $data{$bn}->{lcase($1)}=[parse_line(DELIM, 0, $2)], next;

    # if we came this far, the syntax couldn't be validated:
    croak "Syntax error on line $. '$_'";
  }

  $self->{_DATA} = \%data;

  close($fh) or die $!;
  return 1;
}


sub lcase {
  my $str = shift;
  $LC or return $str;
  return lc($str);
}




sub parse_cfg_file {
  my ($self, $fh) = @_;

  unless ( defined $fh ) {
    $fh = $self->{_FILE_HANDLE} or die "'_FILE_HANDLE' is not defined";
  }

  seek($fh, 0, 0) or croak "Couldn't seek($fh, 0, 0) in '$self->{_FILE_NAME}':$!";

  while ( <$fh> ) {
    # skipping comments and empty lines:
    /^(\n|\#)/  and next;
    /\w/        or  next;

    # stripping $/:
    chomp();

    # parsing key/value pairs
    /^\s*([\w-]+)\s+(.*)\s*$/ and $self->{_DATA}->{lcase($1)}=[parse_line(DELIM, 0, $2)], next;

    # if we came this far, the syntax couldn't be validated:
    croak "Syntax error on line $.: '$_'";
  }

  close($fh) or die $!;
  return 1;
}






sub parse_http_file {
  my ($self, $fh) = @_;

  unless ( defined $fh ) {
    $fh = $self->{_FILE_HANDLE} or die "'_FILE_HANDLE' is not defined";
  }


  seek($fh, 0, 0) or croak "Couldn't seek($fh, 0, 0) in '$self->{_FILE_NAME}':$!";

  while ( <$fh> ) {
    # skipping comments and empty lines:
    /^(\n|\#)/  and next;
    /\w/        or  next;

    # stripping $/:
    chomp();

    # parsing key/value pairs:
    /^\s*([\w-]+)\s*:\s*(.*)$/  and $self->{_DATA}->{lcase($1)}=[parse_line(DELIM, 0, $2)], next;

    # if we came this far, the syntax couldn't be validated:
    croak "Syntax error on line $.: '$_'";
  }

  close($fh) or die $!;
  return 1;
}



sub param {
  my $self = shift;

  # If called with no arguments, return all the
  # possible keys
  unless ( @_ ) {
    return keys %{$self->{_DATA}};
  }

  # if called with a single argument, return the value
  # matching this key
  if ( @_ == 1) {
    my $value = $self->get_param(@_) or return;

    # If array has a single element, return it
    if ( @{$value} == 1 ) {
      return $value->[0];
    }
    # otherwise, return value depending on the context
    return wantarray ? @{$value} : $value;
  }

  # if we come this far, we were called with multiple
  # arguments. Go figure!
  my $args = {
    '-name',   undef,
    '-value',  undef,
    '-values', undef,
    '-block',  undef,
    @_
  };

  if ( $args->{'-name'} && ($args->{'-value'} || $args->{'-values'}) ) {
    # OBJ->param(-name=>'..', -value=>'...') syntax:
    return $self->set_param($args->{'-name'}, $args->{'-value'}||$args->{'-values'});

  }

  if ( $args->{'-name'} ) {
    # OBJ->param(-name=>'...') syntax:

    my $value = $self->get_param($args->{'-name'});

     # If array has a single element, return it
    if ( @{$value} == 1 ) {
      return $value->[0];
    }
    # otherwise, return value depending on the context
    return wantarray ? @{$value} : $value;

  }

  if ( @_ % 2 ) {
    croak "param(): illegal syntax";
  }

  my $nset = 0;
  for ( my $i = 0; $i < @_; $i += 2 ) {
    $self->set_param($_[$i], $_[$i+1]) && $nset++;
  }

  return $nset;
}




sub get_param {
  my ($self, $arg) = @_;

  unless ( $arg ) {
    croak "Usage: OBJ->get_param(\$key)";
  }

  $arg = lcase($arg);

  my $syntax = $self->{_SYNTAX} or die "'_SYNTAX' is undefined";

  # If it was an ini-style, we should first
  # split the argument into its block name and key
  # components:
  if ( $syntax eq 'ini' ) {
    my ($block_name, $key) = $arg =~ m/^([^\.]+)\.(.*)$/;

    if ( $block_name && $key ) {
      return $self->{_DATA}->{$block_name}->{$key};

    }

    # if it really was an ini-styled file, probably simplified
    # syntax was used. In this case we assumed $DEFAULTNS
    # as the default blockname and treat $arg as the key name
    return $self->{_DATA}->{$DEFAULTNS}->{$arg};
  }

  return $self->{_DATA}->{$arg};
}





sub set_param {
  my ($self, $key, $value) = @_;

  my $syntax = $self->{_SYNTAX} or die "'_SYNTAX' is not defined";

  unless ( ref($value) eq 'ARRAY' ) {
    $value = [$value];
  }

  $key = lcase($key);

  # If it was an ini syntax, we should first split the $key
  # into its block_name and key components
  if ( $syntax eq 'ini' ) {
    my ($bn, $k) = $key =~ m/^([^\.]+)\.(.*)$/;

    if ( $bn && $k ) {
      return $self->{_DATA}->{$bn}->{$k} = $value;
    }

    # most likely the user is assuming default namespace then?
    # Let's hope!
    return $self->{_DATA}->{$DEFAULTNS}->{$key} = $value;
  }

  return $self->{_DATA}->{$key} = $value;
}






# returns all the keys as a hash or hashref
sub vars {
  my $self = shift;

  my $syntax = $self->{_SYNTAX} or die "'_SYNTAX' is not defined";

  my %vars = ();
  if ( $syntax eq 'ini' ) {
    while ( my ($block, $values) = each %{$self->{_DATA}} ) {
      while ( my ($k, $v) = each %{$values} ) {
        $vars{"$block.$k"} = @$v == 1 ? $v->[0] : $v;
      }
    }

  } else {
    while ( my ($k, $v) = each %{$self->{_DATA}} ) {
      $vars{$k} = @$v ? $v->[0] : $v;
    }
  }

  return wantarray ? %vars : \%vars;
}






sub write {
  my ($self, $file) = @_;

  $file ||= $self->{_FILE_NAME} or die "Neither '_FILE_NAME' nor \$filename defined";


  sysopen(FH, $file, O_WRONLY|O_CREAT|O_TRUNC, 0600) or croak "Couldn't open '$file': $!";
  unless ( flock(FH, LOCK_EX) ) {
    croak "Couldn't lock $file: $!";
  }
  print FH $self->as_string();
  close(FH) or die "Couldn't write into '$file': $!";

  return 1;
}



sub save {
  my $self = shift;

  return $self->write(@_);
}


# generates a writable string
sub as_string {
  my $self = shift;

  my $syntax = $self->{_SYNTAX} or die "'_SYNTAX' is not defiend";
  my $sub_syntax = $self->{_SUB_SYNTAX};

  my $STRING = undef;

  if ( $syntax eq 'ini' ) {
    $STRING .= "; Config::Simple $VERSION\n\n";
    while ( my ($block_name, $key_values) = each %{$self->{_DATA}} ) {
      unless ( $sub_syntax eq 'simple-ini' ) {
        $STRING .= sprintf("[%s]\n", $block_name);
      }
      while ( my ($key, $value) = each %{$key_values} ) {
        my $values = join ', ', map { quote_values($_) } @$value;
        $STRING .= sprintf("%s=%s\n", $key, $values );
      }
    }

  } elsif ( $syntax eq 'http' ) {
    $STRING .= "# Config::Simple $VERSION\n\n";
    while ( my ($key, $value) = each %{$self->{_DATA}} ) {
      my $values = join ', ', map { quote_values($_) } @$value;
      $STRING .= sprintf("%s: %s\n", $key, $values);
    }

  } elsif ( $syntax eq 'simple' ) {
    $STRING .= "# Config::Simple $VERSION\n\n";
    while ( my ($key, $value) = each %{$self->{_DATA}} ) {
      my $values = join ', ', map { quote_values($_) } @$value;
      $STRING .= sprintf("%s %s\n", $key, $values);
    }
  }

  $STRING .= "\n";

  return $STRING;
}









# quotes each value before saving into file
sub quote_values {
  my $string = shift;

  if ( ref($string) ) {
    $string = $_[0];
  }

  if ( $string =~ m/\W/ ) {
    $string =~ s/"/\\"/g;
    return sprintf("\"%s\"", $string);
  }

  return $string;
}



sub dump {
  my ($self, $file, $indent) = @_;

  require Data::Dumper;

  my $d = new Data::Dumper([$self], [ref $self]);
  $d->Indent($indent||2);

  if ( defined $file ) {
    sysopen(FH, $file, O_WRONLY|O_CREAT|O_TRUNC, 0600) or die $!;
    print FH $d->Dump();
    close(FH) or die $!;
  }
  return $d->Dump();
}


sub verbose {
  DEBUG or return;
  carp "****[$0]: " .  join ("", @_);
}




# -------------------
# deprecated methods
# -------------------

sub write_string {
  my $self = shift;

  return $self->as_string(@_);
}

sub hashref {
  my $self = shift;

  return scalar( $self->vars() );
}

sub param_hash {
  my $self = shift;

  return ($self->vars);
}







sub TIEHASH {
  croak "tie() interface still needs to be implemented";
}


1;
__END__;

=pod

=head1 NAME

Config::Simple - simple configuration file class

=head1 SYNOPSIS

  use Config::Simple;

  my $cfg = new Config::Simple('app.cfg') or die Config::Simple->error();

  # reading
  my $user = $cfg->param("User");

  # updating:
  $cfg->param(User=>'sherzodr');

  # saving
  $cfg->write();
  # or
  $cfg->save()


=head1 DESCRIPTION

Reading and writing configuration files is one of the most frequent
aspects of any software design. Config::Simple is the library to help
you with it.

=head1 ONE SIZE FITS ALL

Well, almost all. Cofig::Simple supports variety of configuration file
formats. Following are some overview of configuration file formats:

=head2 SIMPLE CONFIGURATION

Simple syntax is what you need for most of your projects. These
are, as the name asserts, the simplest. File consists of key/value
pairs, delimited by nothing but whitespace. Keys (variables) should
be strictly alpha-numeric with possible dashes (-). Values can hold
any arbitrary text. Here is an example of such a configuration file:

  Alias     /exec
  TempFile  /usr/tmp

Comments start with a pound ('#') sign and cannot share the same
line with other configuration data.

=head2 HTTP-LIKE SYNTAX

This format of seperating key/value pairs is used by HTTP messages.
Each key/value is seperated by semi-colon (:). Keys are alphanumeric
strings with possible '-'. Values can be any artibtrary text:

Example:

  Alias: /exec
  TempFile: /usr/tmp

It is OK to have spaces around ':'. Comments start with '#' and cannot
share the same line with other configuration data

=head2 INI-FILE

This configuration files are more native to Win32 systems. Data
is organized in blocks. Each key/value pair is delimited with an
equal (=) sign. Blocks are declared on their own lines inclosed in
'[' and ']':

  [BLOCK1]
  KEY1=VALUE1
  KEY2=VALUE2


  [BLOCK2]
  KEY1=VALUE1
  KEY2=VALUE2

This is the perfect choice if you need to organize your configuration
file into categories.

ADVICE: Avoid using none alpha-numeric characters as blockname or key. If value
consists of none alpha-numeric characters, its better to inclose them in
double quotes. Althogh these constraints are not mandatory while using
Config::Simple, they will help to make your configuration files more portable.

  [site]
  url="http://www.handalak.com"
  title="Website of a \"Geek\""
  author=sherzodr

=head2 SIMPLIFIED INI-FILE

If you do not want to declear several blocks, you can easily leave out block declaration.
They will be assigned to a default block automatically:

  url = "http://www.handalak.com"

is the same as saying:

  [default]
  url = "http://www.handalak.com"

Comments can begin with either pound ('#') or semi-colon (';'). Each comment
should reside on its own line

=head1 PROGRAMMING STYLE

=head2 READING THE CONFIGURATION FILE

To read the existing configuration file, simply pass its name
to the constructor new() while creating the Config::Simple object:

  $cfg = new Config::Simple('app.cfg');

The above line reads and parses the configuration file accordingly.
It tries to guess which syntax is used. Alternatively, you can
create an empty object, and only then read the configuration file in:

  $cfg = new Config::Simple();
  $cfg->read('app.cfg');

As in the first example, read() tries to guess the syntax used in the
configuration file.

If, for any reason, it fail to guess the syntax correctly (which is less likely),
you can try to debug by using its guess_syntax() method. It expects
filehandle for a  configuration file and returns the name of a style.

  $cfg = new Config::Simple();

  open(FH, "app.cfg");
  printf("This file uses '%s' syntax\n", $cfg->quess_syntax(\*FH));

=head2 ACCESSING VALUES

After you read the configuration file into Config::Simple object
succesfully, you can use param() method to access the configuration values.
For example:

  $user = $cfg->param("User");

will return the value of "User" from either simple configuration file, or
http-styled configuration as well as simplified ini-files. To acccess the
value from a traditional ini-file, consider the following syntax:

  $user = $cfg->param("mysql.user");

The above returns the value of "user" from within "[mysql]" block. Notice the
use of dot "." to delimit block and key names.

Config::Simple also supports vars() method, which, depending on the context
used, returns all the values either as hashref or hash:

  my %Config = $cfg->vars();

  print "Username: $Config{User}";

  # If it was a traditional ini-file:
  print "Username: $Config{'mysql.user'}";

If you call vars() in scalar context, you will end up with a refrence to a hash:

  my $Config = $cfg->vars();

  print "Username: $Config->{User}";

=head2 UPDATING THE VALUES

Configuration values, once read into Config::Simple, can be updated from within
your programs by using the same param() method used for accessing them. For example:

  $cfg->param("User", "sherzodR");

The above line changes the value of "User" to "sherzodR". Similar syntax is applicable
for ini-files as well:

  $cfg->param("mysql.user", "sherzodR");

=head2 SAVING/WRITING CONFIGURATION FILES

The above updates to the configuration values are in-memory operations. They
do not reflect in the file itself. To modify the files accordingly, you need to
call either "write()" or "save()" methods on the object:

  $cfg->write();

The above line writes the modifications to the configuration file. Alternatively,
you can pass a name to either write() or save() to indicate the name of the
file to create instead of modifying existing configuration file:

  $cfg->write("app.cfg.bak");

If you want the changes saved all the time, you can turn C<autosave> mode on
by passing true value to $cfg->autosave():

  $cfg->autosave(1);

=head2 MULTIPLE VALUES

Ever wanted a key in the configuration file to hold array of values? Well, I did.
That's why Config::Simple supports this fancy feature as well. Simply seperate your values
with a comma:

  Files hp.cgi, template.html, styles.css

Now param() method returns an array of values split at comma:

  @files = $cfg->param("Files");
  unlink $_ for @files;

If you want a comma as part of a value, enclose the value(s) in double quotes:

  CVSFiles "hp.cgi,v", "template.html,v", "styles.css,v"

In case you want either of the values to hold literal quote ("), you can
escape it with a backlash:

  SiteTitle "sherzod \"The Geek\""

=head1 CASE SENSITIVITY

By default, configuration file keys and values are case sensitive. Which means,
$cfg->param("User") and $cfg->param("user") are refering to two different values.
But it is possible to force Config::Simple to ignore cases all together by enabling
C<-lc> switch while loading the library:

  use Config::Simple ('-lc');

WARNING: If you call write() or save(), while working on C<-lc> mode, all the case
information of the original file will be lost. So use it if you know what you're doing.

=head1 CREDITS

=over 4

=item Michael Caldwell (mjc@mjcnet.com)

whitespace support, C<-lc> switch

=item Scott Weinstein (Scott.Weinstein@lazard.com)

bug fix in TIEHASH

=item Ruslan U. Zakirov <cubic@wr.miee.ru>

Default namespace suggestion and patch

=back

=head1 COPYRIGHT

  Copyright (C) 2002-2003 Sherzod B. Ruzmetov.

  This softeware is free library. You can modify and/or distribute it
  under the same terms as Perl itself

=head1 AUTHOR

  Sherzod B. Ruzmetov E<lt>sherzodr@cpan.orgE<gt>
  URI: http://author.handalak.com

=cut




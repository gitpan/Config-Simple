package Config::Simple;

# $Id: Simple.pm,v 3.22 2003/02/21 23:07:31 sherzodr Exp $

use strict;
# uncomment the following line while debugging. Otherwise,
# it's too slow for production environment
#use diagnostics;
use Carp;
use Fcntl (':DEFAULT', ':flock');
use Text::ParseWords 'parse_line';
use vars qw($VERSION $DEFAULTNS $LC $USEQQ $errstr);

$VERSION   = '4.3';
$DEFAULTNS = 'default';

sub import {
  for ( @_ ) {
    $LC     = ($_ eq '-lc')     and next;
    $USEQQ  = ($_ eq '-strict') and next;    
  }
}



# delimiter used by Text::ParseWords::parse_line()
sub READ_DELIM () { return '\s*,\s*' }

# delimiter used by as_string()
sub WRITE_DELIM() { return ', '      }
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
    _ARGS           => {},
    _OO_INTERFACE   => 1,
  };
  bless ($self, $class);
  $self->_init(@_) or return;
  return $self;
}




sub DESTROY {
  my $self = shift;
  
  # if it was an auto save mode, write the changes
  # back. Currently it doesn't quite care if they
  # were modified or not.
  if ( $self->autosave() ) {
    $self->write();
  }
}




# initialize the object
sub _init {
  my $self = shift;

  if ( @_ == 1 ) {
    return $self->read($_[0]);
  } elsif ( @_ % 2 ) {
    croak "new(): Illegal arguments detected";
  } else {
    $self->{_ARGS} = { @_ };
  }
  # If filename was passed, call read()
  if ( exists ($self->{_ARGS}->{filename}) ) {
    return $self->read( $self->{_ARGS}->{filename} );
  }
  # if syntax was given, call syntax()
  if ( exists $self->{_ARGS}->{syntax} ) {
    $self->syntax($self->{_ARGS}->{syntax});
  }
  return 1;
}



sub autosave {
  my ($self, $bool) = @_;

  if ( defined $bool ) {
    $self->{_ARGS}->{autosave} = $bool;
  }
  return $self->{_ARGS}->{autosave};
}


sub syntax {
  my ($self, $syntax) = @_;  

  if ( defined $syntax ) {
    $self->{_SYNTAX} = $syntax;
  }  
  return $self->{_SYNTAX};
}




sub read {
  my ($self, $file) = @_;

  if ( defined $self->{_FILE_HANDLE} ) {
    croak "Open file handle detected. If you're trying to parse another file, close() it first.";
  }
  unless ( $file ) {
    croak "Usage: OBJ->read(\$file_name)";
  }
  unless ( sysopen(FH, $file, O_RDONLY) ) {
    $self->error("Couldn't read '$file': $!");
    return undef;
  }
  $self->{_FILE_NAME}   = $file;
  $self->{_FILE_HANDLE} = \*FH;
  $self->{_SYNTAX} = $self->guess_syntax(\*FH) or return undef;

  # call respective parsers
  
  $self->{_SYNTAX} eq 'ini'     and return $self->parse_ini_file(\*FH);
  $self->{_SYNTAX} eq 'simple'  and return $self->parse_cfg_file(\*FH);
  $self->{_SYNTAX} eq 'http'    and return $self->parse_http_file(\*FH);
}


sub close {
  my $self = shift;

  my $fh = $self->{_FILE_HANDLE} or return;
  unless ( close($fh) ) {
    $self->error("couldn't close the file: $!");
    return undef;
  }  
  return 1;
}

# tries to guess the syntax of the configuration file.
# returns 'ini', 'simple' or 'http'.
sub guess_syntax {
  my ($self, $fh) = @_;

  unless ( defined $fh ) {
    $fh = $self->{_FILE_HANDLE} or die "'_FILE_HANDLE' is not defined";
  }
  unless ( seek($fh, 0, 0) ) {
    $self->error("Couldn't seek($fh, 0, 0): $!");
    return undef;
  }

  # now we keep reading the file line by line untill we can identify the
  # syntax
  verbose("Trying to guess the file syntax...");
  my ($syntax, $sub_syntax);
  while ( <$fh> ) {
    # skipping empty lines and comments. They don't tell much anyway
    /^(\n|\#|;)/ and next;

    # If there's no alpha-numeric value in this line, ignore it
    /\w/ or next;

    # trim $/
    chomp();

    # If there's a block, it is an ini syntax
    /^\s*\[\s*[^\]]+\s*\]\s*$/  and $syntax = 'ini', last;

    # If we can read key/value pairs separated by '=', it still
    # is an ini syntax with a default block assumed
    /^\s*[^=]+\s*=\s*.*\s*$/    and $syntax = 'ini', $self->{_SUB_SYNTAX} = 'simple-ini', last;

    # If we can read key/value pairs separated by ':', it is an
    # http syntax
    /^\s*[\w-]+\s*:\s*.*\s*$/   and $syntax = 'http', last;

    # If we can read key/value pairs separated by just whites,
    # it is a simple syntax.
    /^\s*[\w-]+\s+.*$/          and $syntax = 'simple', last;    
  }

  if ( $syntax ) {
    return $syntax;
  }

  $self->error("Couldn't identify the syntax used");
  return undef;
    

}







sub parse_ini_file {
  my ($self, $fh) = @_;
  
  seek($fh, 0, 0) or croak "Couldn't seek($fh, 0, 0) in '$self->{_FILE_NAME}': $!";

  my $bn = $DEFAULTNS;
  my %data = ();
  while ( <$fh> ) {
    # skipping comments and empty lines:
    /^(\n|\#|;)/  and next;
    /\w/          or  next;    
    chomp();
    s/^\s+//g;
    s/\s+$//g;
    # parsing the block name:
    /^\s*\[\s*([^\]]+)\s*\]$/       and $bn = lcase($1), next;
    # parsing key/value pairs
    /^\s*([^=]*\w)\s*=\s*(.*)\s*$/  and $data{$bn}->{lcase($1)}=[parse_line(READ_DELIM, 0, $2)], next;
    # if we came this far, the syntax couldn't be validated:
    $self->error("Syntax error on line $. '$_'");
    return undef;
  }
  $self->{_DATA} = \%data;
  CORE::close($fh) or die $!;
  return wantarray ? %data : \%data;
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
  my %data = ();
  while ( <$fh> ) {
    # skipping comments and empty lines:
    /^(\n|\#)/  and next;
    /\w/        or  next;    
    chomp();
    s/^\s+//g;
    s/\s+$//g;
    # parsing key/value pairs
    /^\s*([\w-]+)\s+(.*)\s*$/ and $data{lcase($1)}=[parse_line(READ_DELIM, 0, $2)], next;
    # if we came this far, the syntax couldn't be validated:
    $self->error("Syntax error on line $.: '$_'");
    return undef;
  }
  $self->{_DATA} = \%data;
  CORE::close($fh) or die $!;
  return wantarray ? %data : \%data;
}






sub parse_http_file {
  my ($self, $fh) = @_;

  unless ( defined $fh ) {
    $fh = $self->{_FILE_HANDLE} or die "'_FILE_HANDLE' is not defined";
  }
  seek($fh, 0, 0) or croak "Couldn't seek($fh, 0, 0) in '$self->{_FILE_NAME}':$!";
  my %data = ();
  while ( <$fh> ) {
    # skipping comments and empty lines:
    /^(\n|\#)/  and next;
    /\w/        or  next;
    # stripping $/:
    chomp();
    s/^\s+//g;
    s/\s+$//g;
    # parsing key/value pairs:
    /^\s*([\w-]+)\s*:\s*(.*)$/  and $data{lcase($1)}=[parse_line(READ_DELIM, 0, $2)], next;
    # if we came this far, the syntax couldn't be validated:
    $self->error("Syntax error on line $.: '$_'");
    return undef;
  }
  $self->{_DATA} = \%data;
  CORE::close($fh) or die $!;
  return wantarray ? %data : \%data;
}



sub param {
  my $self = shift;

  # If called with no arguments, return all the
  # possible keys
  unless ( @_ ) {
    my $vars = $self->vars();
    return keys %$vars;
  }
  # if called with a single argument, return the value
  # matching this key
  if ( @_ == 1) {
    return $self->get_param(@_);    
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
    return $self->get_param($args->{'-name'});
     
  }
  if ( $args->{'-block'} && ($args->{'-values'} || $args->{'-value'}) ) {
    return $self->set_block($args->{'-block'}, $args->{'-values'}||$args->{'-value'});
  }
  if ( $args->{'-block'} ) {
    return $self->get_block($args->{'-block'});
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
  my $rv = undef;
  if ( $syntax eq 'ini' ) {
    my ($block_name, $key) = $arg =~ m/^([^\.]+)\.(.*)$/;
    if ( $block_name && $key ) {
      $rv = $self->{_DATA}->{$block_name}->{$key};
    } else {
      $rv = $self->{_DATA}->{$DEFAULTNS}->{$arg};
    }
  } else {
    $rv = $self->{_DATA}->{$arg};
  }

  defined($rv) or return;

  for ( my $i=0; $i < @$rv; $i++ ) {
    $rv->[$i] =~ s/\\n/\n/g;
  }  
  return @$rv==1 ? $rv->[0] : (wantarray ? @$rv : $rv);
}




sub get_block {
  my ($self, $block_name)  = @_;

  unless ( $self->syntax() eq 'ini' ) {
    croak "get_block() is supported only in 'ini' files";
  }
  my $rv = {};
  while ( my ($k, $v) = %{$self->{_DATA}->{$block_name}} ) {
    $v =~ s/\\n/\n/g;
    $rv->{$k} = $v;
  }
  return $rv;
}





sub set_block {
  my ($self, $block_name, $values) = @_;

  unless ( $self->syntax() eq 'ini' ) {
    croak "set_block() is supported only in 'ini' files";
  }
  my $processed_values = {};
  while ( my ($k, $v) = each %$values ) {
    $v =~ s/\n/\\n/g;
    $processed_values->{$k} = [$v];
  }

  $self->{_DATA}->{$block_name} = $processed_values;
}





sub set_param {
  my ($self, $key, $value) = @_;

  my $syntax = $self->{_SYNTAX} or die "'_SYNTAX' is not defined";  
  if ( ref($value) eq 'ARRAY' ) {
    for (my $i=0; $i < @$value; $i++ ) {
      $value->[$i] =~ s/\n/\\n/g;
    }
  } else {
    $value =~ s/\n/\\n/g;
  }
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
    # most likely the user is assuming default name space then?
    # Let's hope!
    return $self->{_DATA}->{$DEFAULTNS}->{$key} = $value;
  }
  return $self->{_DATA}->{$key} = $value;
}




sub delete {
  my ($self, $key) = @_;

  my $syntax = $self->syntax() or die "No 'syntax' is defined";
  if ( $syntax eq 'ini' ) {
    my ($bn, $k) = $key =~ m/([^\.]+)\.(.*)/;
    if ( defined($bn) && defined($k) ) {
      delete $self->{_DATA}->{$bn}->{$k};
    } else {
      delete $self->{_DATA}->{$DEFAULTNS}->{$key};
    }
    return 1;
  }
  delete $self->{_DATA}->{$key};
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

  unless ( sysopen(FH, $file, O_WRONLY|O_CREAT|O_TRUNC, 0600) ) {
    $self->error("'$file' couldn't be opened for writing: $!");
    return undef;
  }
  unless ( flock(FH, LOCK_EX) ) {
    $self->error("'$file' couldn't be locked: $!");
    return undef;
  }
  print FH $self->as_string();
  unless ( CORE::close(FH) ) {
    $self->error("Couldn't write into '$file': $!");
    return undef;
  }
  return 1;
}



sub save {
  my $self = shift;
  return $self->write(@_);
}


# generates a writable string
sub as_string {
  my $self = shift;

  my $syntax = $self->{_SYNTAX} or die "'_SYNTAX' is not defined";
  my $sub_syntax = $self->{_SUB_SYNTAX} || '';
  my $STRING = undef;
  if ( $syntax eq 'ini' ) {
    $STRING .= "; Config::Simple $VERSION\n\n";
    while ( my ($block_name, $key_values) = each %{$self->{_DATA}} ) {
      unless ( $sub_syntax eq 'simple-ini' ) {
        $STRING .= sprintf("[%s]\n", $block_name);
      }
      while ( my ($key, $value) = each %{$key_values} ) {
        my $values = join (WRITE_DELIM, map { quote_values($_) } @$value) or next;
        $STRING .= sprintf("%s=%s\n", $key, $values );
      }
      $STRING .= "\n";
    }
  } elsif ( $syntax eq 'http' ) {
    $STRING .= "# Config::Simple $VERSION\n\n";
    while ( my ($key, $value) = each %{$self->{_DATA}} ) {
      my $values = join (WRITE_DELIM, map { quote_values($_) } @$value) or next;
      $STRING .= sprintf("%s: %s\n", $key, $values);
    }
  } elsif ( $syntax eq 'simple' ) {
    $STRING .= "# Config::Simple $VERSION\n\n";
    while ( my ($key, $value) = each %{$self->{_DATA}} ) {
      my $values = join (WRITE_DELIM, map { quote_values($_) } @$value) or next;
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
  if ( $USEQQ && ($string =~ m/\W/) ) {
    $string =~ s/"/\\"/g;
    return sprintf("\"%s\"", $string);
  }
  return $string;
}





sub error {
  my ($self, $msg) = @_;

  if ( $msg ) {
    $errstr = $msg;
  }
  return $errstr;
}





sub dump {
  my ($self, $file, $indent) = @_;

  require Data::Dumper;
  my $d = new Data::Dumper([$self], [ref $self]);
  $d->Indent($indent||2);
  if ( defined $file ) {
    sysopen(FH, $file, O_WRONLY|O_CREAT|O_TRUNC, 0600) or die $!;
    print FH $d->Dump();
    CORE::close(FH) or die $!;
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

sub errstr {
  my $self = shift;
  return $self->error(@_);
}


#------------------
# tie() interface
#------------------

sub TIEHASH {
  my ($class, $file) = @_;

  unless ( defined $file ) {
    croak "Usage: tie \%config, 'Config::Simple', \$filename";
  }
  
  return $class->new($file)
}


sub FETCH {
  my $self = shift;

  return $self->param(@_);
}


sub STORE {
  my $self = shift;

  return $self->param(@_);
}



sub DELETE {
  my $self = shift;

  return $self->delete(@_);
}






1;
__END__;

=pod

=head1 NAME

Config::Simple - simple configuration file class

=head1 SYNOPSIS

  use Config::Simple;

  # OO interface:
  $cfg = new Config::Simple('app.cfg');
  $user = $cfg->param("User");    # read the value  
  $cfg->param(User=>'sherzodr');  # update  
  my %Config = $cfg->vars();      # load everything into %Config
  $cfg->write();                  # saves the changes to file
    

  # tie interface:
  tie my %Config, "Config::Simple", "app.cgi";    
  $user = $Config{'User'};  
  $Config{'User'} = 'sherzodr';  
  tied(%Config)->write();

=head1 ABSTRACT

Reading and writing configuration files is one of the most frequent
aspects of any software design. Config::Simple is the library to help
you with it.

Config::Simple is a class representing configuration file object. 
It supports several configuration file syntax and tries
to identify the file syntax to parse them accordingly. Library supports
parsing, updating and creating configuration files. 

=head1 ABOUT CONFIGURATION FILES

Keeping configurable variables in your program source code is ugly, really.
And for people without much of a programming experience, configuring
your programs is like performing black magic. Besides, if you need to
access these values from within multiple files, or want your programs
to be able to update configuration files, you just have to store them in 
an external file. That's where Config::Simple comes into play, making it
very easy to read and write configuration files.

If you have never used configuration files before, here is a brief
overview of various syntax to choose from.

=head2 SIMPLE CONFIGURATION FILE

Simple syntax is what you need for most of your projects. These
are, as the name asserts, the simplest. File consists of key/value
pairs, delimited by nothing but white space. Keys (variables) should
be strictly alpha-numeric with possible dashes (-). Values can hold
any arbitrary text. Here is an example of such a configuration file:

  Alias     /exec
  TempFile  /usr/tmp

Comments start with a pound ('#') sign and cannot share the same
line with other configuration data.

=head2 HTTP-LIKE SYNTAX

This format of separating key/value pairs is used by HTTP messages.
Each key/value is separated by semi-colon (:). Keys are alphanumeric
strings with possible '-'. Values can be any arbitrary text:

Example:

  Alias: /exec
  TempFile: /usr/tmp

It is OK to have spaces around ':'. Comments start with '#' and cannot
share the same line with other configuration data.

=head2 INI-FILE

These configuration files are more native to Win32 systems. Data
is organized in blocks. Each key/value pair is delimited with an
equal (=) sign. Blocks are declared on their own lines enclosed in
'[' and ']':

  [BLOCK1]
  KEY1=VALUE1
  KEY2=VALUE2


  [BLOCK2]
  KEY1=VALUE1
  KEY2=VALUE2

Your Winamp 2.x play list is an example of such a configuration file.

This is the perfect choice if you need to organize your configuration
file into categories:

  [site]
  url="http://www.handalak.com"
  title="Web site of a \"Geek\""
  author=sherzodr

  [mysql]  
  dsn="dbi:mysql:db_name;host=handalak.com"
  user=sherzodr
  password=marley01

=head2 SIMPLIFIED INI-FILE

These files are pretty much similar to traditional ini-files, except they don't
have any block declarations. This style is handy if you do not want any categorization
in your configuration file, but still want to use '=' delimited key/value pairs. 
While working with such files, Config::Simple assigns them to a default block, 
called 'default' by default :-).

  url = "http://www.handalak.com"

Comments can begin with either pound ('#') or semi-colon (';'). Each comment
should reside on its own line

=head1 PROGRAMMING STYLE

=head2 READING THE CONFIGURATION FILE

To read the existing configuration file, simply pass its name
to the constructor new() while initializing the object:

  $cfg = new Config::Simple('app.cfg');

The above line reads and parses the configuration file accordingly.
It tries to guess which syntax is used by parsing the file to guess_syntax() method.
Alternatively, you can create an empty object, and only then read the configuration file in:

  $cfg = new Config::Simple();
  $cfg->read('app.cfg');

As in the first example, read() also calls guess_syntax() method on the file.

If, for any reason, it fails to guess the syntax correctly (which is less likely),
you can try to debug by using its guess_syntax() method. It expects
file handle for a  configuration file and returns the name of a syntax. Return
value is one of "ini", "simple" or "http".

  $cfg = new Config::Simple();

  open(FH, "app.cfg");
  printf("This file uses '%s' syntax\n", $cfg->guess_syntax(\*FH));

=head2 ACCESSING VALUES

After you read the configuration file in successfully, you can use param() 
method to access the configuration values. For example:

  $user = $cfg->param("User");

will return the value of "User" from either simple configuration file, or
http-styled configuration as well as simplified ini-files. To access the
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

If you call vars() in scalar context, you will end up with a reference to a hash:

  my $Config = $cfg->vars();
  print "Username: $Config->{User}";

=head2 UPDATING THE VALUES

Configuration values, once read into Config::Simple, can be updated from within
your program by using the same param() method used for accessing them. For example:

  $cfg->param("User", "sherzodR");

The above line changes the value of "User" to "sherzodR". Similar syntax is applicable
for ini-files as well:

  $cfg->param("mysql.user", "sherzodR");

If the key you're trying to update does not exist, it will be created. For example,
to add a new "[session]" block to your ini-file, assuming this block doesn't already
exist:

  $cfg->param("session.life", "+1M");

You can also delete values calling delete() method with the name of the variable:

  $cfg->delete('mysql.user'); # deletes 'user' under [mysql] block


=head2 SAVING/WRITING CONFIGURATION FILES

The above updates to the configuration values are in-memory operations. They
do not reflect in the file itself. To modify the files accordingly, you need to
call either "write()" or "save()" methods on the object:

  $cfg->write();

The above line writes the modifications to the configuration file. Alternatively,
you can pass a name to either write() or save() to indicate the name of the
file to create instead of modifying existing configuration file:

  $cfg->write("app.cfg.bak");

If you want the changes saved at all times, you can turn C<autosave> mode on
by passing true value to $cfg->autosave(). It will make sure before your program
is terminated, all the configuration values are written back to its file:

  $cfg = new Config::Simple('aff.cfg');
  $cfg->autosave(1);

=head2 CREATING CONFIGURATION FILES

Occasionally, your programs may want to create their own configuration files
on the fly, possibly from a user input. To create a configuration file from
scratch using Config::Simple, simply create an empty configuration file object
and define your syntax. You can do it by either passing "syntax" option to new(),
or by calling syntax() method. Then play with param() method as you normally would.
When you're done, call write() method with the name of the configuration file:

  $cfg = new Config::Simple(syntax=>'ini');
  # or you could also do:
  # $cfg->autosave('ini')

  $cfg->param("mysql.dsn", "DBI:mysql:db;host=handalak.com");
  $cfg->param("mysql.user", "sherzodr");
  $cfg->param("mysql.pass", 'marley01');
  $cfg->param("site.title", 'sherzodR "The Geek"');
  $cfg->write("new.cfg");

This creates the a file "new.cfg" with the following content:

  ; Config::Simple 4.1

  [site]
  title=sherzodR "The Geek"

  [mysql]
  pass=marley01
  dsn=DBI:mysql:db;host=handalak.com
  user=sherzodr

Neat, huh? Supported syntax keywords are "ini", "simple" or "http". Currently
there is no support for creating simplified ini-files.

=head2 MULTIPLE VALUES

Ever wanted to define array of values in your single configuration variable? I have!
That's why Config::Simple supports this fancy feature as well. Simply separate your values
with a comma:

  Files hp.cgi, template.html, styles.css

Now param() method returns an array of values:

  @files = $cfg->param("Files");
  unlink $_ for @files;

If you want a comma as part of a value, enclose the value(s) in double quotes:

  CVSFiles "hp.cgi,v", "template.html,v", "styles.css,v"

In case you want either of the values to hold literal quote ("), you can
escape it with a backlash:

  SiteTitle "sherzod \"The Geek\""

=head2 TIE INTERFACE

If OO style intimidates you, Config::Simple also supports tie() interface.
This interface allows you to tie() an ordinary Perl hash to the configuration file.
From that point on, you can use the variable as an ordinary Perl hash. 

  tie %Config, "Config::Simple", 'app.cfg';

  # Using %Config as an ordinary hash
  print "Username is '$Config{User}'\n";
  $Config{User} = 'sherzodR';


To access the method provided in OO styntax, you need to get underlying Config::Simple
object. You can do so with tied() function:
  
  tied(%Config)->write();

WARNING: tie interface is experimental and not well tested yet. It also doesn't perform
all the hash manipulating operations of Perl. Let me know if you encounter a problem.

=head1 MISCELLANEOUS

=head2 CASE SENSITIVITY

By default, configuration file keys and values are case sensitive. Which means,
$cfg->param("User") and $cfg->param("user") are referring to two different values.
But it is possible to force Config::Simple to ignore cases all together by enabling
C<-lc> switch while loading the library:

  use Config::Simple ('-lc');

WARNING: If you call write() or save(), while working on C<-lc> mode, all the case
information of the original file will be lost. So use it if you know what you're doing.

=head2 USING QUOTES

Some people suggest if values consist of none alpha-numeric strings, they should be
enclosed in double quotes. Well, says them! Although Config::Simple supports parsing
such configuration files already, it doesn't follow this rule while writing them. 
If you really need it to generate such compatible configuration files, C<-strict>
switch is what you need:

  use Config::Simple '-strict';

Now, when you write the configuration data back to files, if values hold any none alpha-numeric
strings, they will be quoted accordingly. All the double quotes that are part of the
value will be escaped with a backslash.

=head2 EXCEPTION HANDLING

Config::Simple doesn't believe in dying that easily (unless you insult it using wrong syntax).
It leaves the decision to the programmer implementing the library. You can use its error() -
class method to access underliying error message. Methods that require you to check
for their return values are read() and write(). If you pass filename to new(), you will
need to check its return value as well. They return any true value indicating success,
undef otherwise:

  # following new always returns true:
  $cfg = new Config::Simple();
  # read() can fail:
  $cfg->read('app.cfg') or die $cfg->error();

  # following new() can fail:
  $cfg = new Config::Simple('app.cfg') or die Config::Simple->error();

  # write() may fail:
  $cfg->write() or die $cfg->error();

=head2 OTHER METHODS

=over 4

=item as_string()

converts in-memory configuration file into a string, which can be then written
into a file. Used by write().

=item dump()

for debugging only. Returns string representation of the in-memory object. Uses
Data::Dumper. 

=item error()

=back

=head1 TODO

=over 4

=item *

Retaining comments while writing the configuration files back and/or methods for
manipulating comments. Everyone loves comments!

=item *

Support for  Apache-like style configuration file. For now, if you want this functionality,
checkout L<Config::General> instead.

=back

=head1 BUGS

Submit bugs to Sherzod B. Ruzmetov E<lt>sherzodr@cpan.orgE<gt>

=head1 CREDITS

=over 4

=item Michael Caldwell (mjc@mjcnet.com)

whitespace support, C<-lc> switch

=item Scott Weinstein (Scott.Weinstein@lazard.com)

bug fix in TIEHASH

=item Ruslan U. Zakirov <cubic@wr.miee.ru>

Default name space suggestion and patch

=back

=head1 COPYRIGHT

  Copyright (C) 2002-2003 Sherzod B. Ruzmetov.

  This software is free library. You can modify and/or distribute it
  under the same terms as Perl itself

=head1 AUTHOR

  Sherzod B. Ruzmetov E<lt>sherzodr@cpan.orgE<gt>
  URI: http://author.handalak.com

=head1 SEE ALSO 

L<Config::General>, L<Config::Simple>, L<Config::Tiny>

=cut




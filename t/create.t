# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More 'no_plan';
use File::Spec;
use Config::Simple '-strict';

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $ini_file = File::Spec->catfile('t', 'new.cfg');

my $cfg = new Config::Simple(syntax=>'ini');


$cfg->param("mysql.dsn", "DBI:mysql:db;host=handalak.com");
$cfg->param("mysql.user", "sherzodr");
$cfg->param("mysql.pass", 'marley01');
$cfg->param("site.title", 'sherzodR "The Geek"');

$cfg->write($ini_file);

ok( -e $ini_file );


# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More 'no_plan';
use File::Spec;
BEGIN { use_ok('Config::Simple') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $ini_file = File::Spec->catfile('t', 'simplified.ini');

my $cfg = new Config::Simple();
$cfg->read($ini_file);
ok($cfg,      "new($ini_file)");

ok($cfg->param("Name") eq "MPFCU");

ok($cfg->param('Library', 'Config::Simple'));

#$cfg->dump('simplified.dump');

#die $cfg->write_string();

$cfg->write();


# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More 'no_plan';
BEGIN { use_ok('Config::Simple') };


#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $file = 'dummy.cfg';
my $cfg =  new Config::Simple();

ok($cfg);
ok($cfg->read($file) ? 0 : 1 );


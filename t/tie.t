# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More 'no_plan';
use File::Spec;
use Config::Simple '-strict';
ok(1);

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $file = File::Spec->catfile('t', 'project.ini');

ok(tie %vars, "Config::Simple", $file);

ok($vars{'Project\2.Name'} eq 'MPFCU');
ok($vars{'Project\1.Count'} == 9);

$vars{'Project\100.Name'} = "Config::Simple";
$vars{'Project\100.Version'} = tied(%vars)->VERSION();
$vars{'Project\100.Versions'} = ["Version 1", "Version 2", "Version 3"]; 

ok($vars{'Project\100.Name'} eq 'Config::Simple');


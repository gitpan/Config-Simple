#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use Test;
use File::Spec;
BEGIN { 
  plan tests => 6;
};
require Config::Simple;
ok(1);
#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $ini_file = File::Spec->catfile('t', 'project.ini');
ok(Config::Simple->import_from($ini_file, 'CFG'));
ok($CFG::PROJECT_COUNT == 3);
ok($CFG::PROJECT_2_NAME eq 'MPFCU');
ok(ref($CFG::PROJECT_100_NAMES) eq 'ARRAY' );
ok($CFG::PROJECT_100_NAMES->[0] eq 'First Name');

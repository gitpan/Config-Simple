#!/usr/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

use strict;
use Test;
use File::Spec;
BEGIN {
  plan tests => 13;
}

require Config::Simple;
ok(1);
#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $ini_file = File::Spec->catfile('t', 'project.ini');

my $cfg = new Config::Simple();
ok($cfg);
ok($cfg->read($ini_file));
ok($cfg->param('Project\2.Name') eq 'MPFCU');
ok($cfg->param('Project\1.Count') == 9);
my $vars = $cfg->vars();
ok($vars->{'Project\2.Name'} eq 'MPFCU');
ok($cfg->param(-name=>'Project\100.Name', -value =>'Config::Simple'));
ok($cfg->param(-name=>'Project\100.Names', -values=>['First Name', 'Second name']));
ok($cfg->param('Project\100.NL', "Hello \nWorld"));
ok($cfg->param('Project\1.Count', 9));

my @names = $cfg->param('Project\100.Names');
ok(scalar(@names) == 2);

my $names = $cfg->param('Project\100.Names');
ok(ref($names) eq 'ARRAY');
ok($cfg->write());





# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More 'no_plan';
use File::Spec;
use Config::Simple ('-lc');
use Data::Dumper;
#########################
ok(1);

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $ini_file = File::Spec->catfile('t', 'project.ini');

my $cfg = new Config::Simple();
$cfg->read($ini_file);
ok($cfg,      "new($ini_file)");

ok($cfg->param('Project\2.Name') eq 'MPFCU');
ok($cfg->param('Project\1.Count') == 9);

my $vars = $cfg->vars();

ok($vars->{'project\2.name'} eq 'MPFCU');

ok($cfg->param(-name=>'Project\100.Name', -value =>'Config::Simple'));
ok($cfg->param(-name=>'Project\100.Names', -values=>['First Name', 'Second name']));

#$cfg->dump('ini.dump');

$cfg->write(File::Spec->catfile('t', 'project-lc.ini'));



# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More 'no_plan';
use File::Spec;
use Config::Simple;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $ini_file = File::Spec->catfile('t', 'project.ini');

my $cfg = new Config::Simple();
$cfg->read($ini_file);
ok($cfg,      "new($ini_file)");

ok($cfg->param('Project\2.Name') eq 'MPFCU');
ok($cfg->param('Project\1.Count') == 9);

my $vars = $cfg->vars();

ok($vars->{'Project\2.Name'} eq 'MPFCU');

ok($cfg->param(-name=>'Project\100.Name', -value =>'Config::Simple'));
ok($cfg->param(-name=>'Project\100.Names', -values=>['First Name', 'Second name']));
ok($cfg->param('Project\100.NL', "Hello \nWorld"));
ok($cfg->param('Project\1.Count', 9));

my @names = $cfg->param('Project\100.Names');
my $names = $cfg->param('Project\100.Names');

ok(ref($names) eq 'ARRAY');
ok(@$names == 2);
is(@names, 2); 


#$cfg->param(-block=>'newProject', -values=>{Name=>'Config::Simple::get_block()'});



ok($cfg->write());





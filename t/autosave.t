
# $Id: autosave.t,v 2.1 2002/11/14 01:14:15 sherzodr Exp $

# Checking if a new configuration file can be created and 
# written from scratch

use strict;
use Test;
use Config::Simple;
use File::Spec;

BEGIN { plan tests => 8 }

ok(1);

my $file = File::Spec->catfile(t=>'autosave.cfg');
my $cfg = new Config::Simple();
$cfg->read($file);
$cfg->autosave(0);

ok($cfg);

ok($cfg->param(), 2);

$cfg->param('author.email', 'sherzodr@cpan.org');

ok($cfg->param(), 3);
ok($cfg->param('author.email'), 'sherzodr@cpan.org');

# saving the file back
$cfg->write();

$cfg = undef;

my $new_cfg = new Config::Simple();
$new_cfg->read($file);
ok($new_cfg->param('author.email'), 'sherzodr@cpan.org');
ok($new_cfg->param(), 3);
ok($new_cfg->delete('author.email'));
$new_cfg->write();


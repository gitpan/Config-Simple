
# $Id: create_new.t,v 2.1 2002/11/14 00:58:49 sherzodr Exp $

# Checking if a new configuration file can be created and 
# written from scratch

use strict;
use Test;
use Config::Simple;
use File::Spec;

BEGIN { plan tests => 4 }

ok(1);

my $file = File::Spec->catfile(t=>'new_file.cfg');
my $cfg = new Config::Simple();

ok($cfg);

$cfg->param('author.f_name', 'Sherzod');
$cfg->param('author.l_name', 'Ruzmetov');
ok($cfg->param(), 2);

$cfg->write($file);

ok (-e $file);




# $Id: defaultns.t,v 2.1 2002/11/09 19:18:24 sherzodr Exp $
use strict;
use Test;
use Config::Simple;
use File::Spec;

BEGIN { plan tests => 7 }

ok(1);

my $file = File::Spec->catfile(t=>'defaultns.cfg');
my $cfg = new Config::Simple($file);

$cfg->autosave(0);

ok ( $cfg );
ok ( $cfg->param(), 4 );
ok ( $cfg->param('default.author'), "sherzodr");
ok ( $cfg->param('default.file'), 'defaultns.cfg');
ok ( $cfg->param('default.version'), '1.0');

ok ( $cfg->param('default.ns'), 'default');



# $Id: default.t,v 2.9 2002/12/17 16:27:20 sherzodr Exp $
use strict;
use Test;
use Config::Simple;
use File::Spec;

BEGIN { plan tests => 10 }

ok(1);

my $file = File::Spec->catfile(t=>'sample.cfg');
my $cfg = new Config::Simple();
$cfg->read($file);

$cfg->autosave(0);

ok ($cfg);
ok ( $cfg->param(), 9 );
ok( $cfg->param("author.l_name"), "Ruzmetov");
ok ( $cfg->param('module.name'), "\"Config::Simple\"");

$cfg->param(-name=>'module.name', -value=>"KewlThing");

ok ( $cfg->param('module.name'), "KewlThing");
ok ( $cfg->param(-name=>'module.name'), "KewlThing");

$cfg->param('module.name', 'Config::Simple');

ok ( $cfg->param('module.name'), "Config::Simple");

my $author_block = $cfg->param(-block=>'author');

ok($author_block->{l_name}, "Ruzmetov");
ok($author_block->{nick}, $cfg->param('author.nick') );

die $cfg->block();



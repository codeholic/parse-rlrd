#!/usr/bin/perl
use strict;
use warnings;

use File::Spec ();
use FindBin ();
use Test::More;

use lib File::Spec->updir;

use Parse::RLRD;

my %grammars = (
    paragraphed => {
        children => [
            { tag => 'p', regex => qr/[\040\t]*\S.*((\r?\n|\n)[\040\t]*\S.*)*/, capture => 0 },
        ],
    },
);

my @tests = (
    {
        test_name   => 'paragraphed',
        grammar     => $grammars{paragraphed},
        data        => "para\n continues\n\nanother para\n \nyet another para",
        expected    => [
            { p => [ "para\n continues" ] },
            "\n\n",
            { p => [ "another para" ] },
            "\n \n",
            { p => [ "yet another para" ] },
        ],
    },
);

plan tests => @tests + keys %grammars;

while (my ($name, $grammar) = each %grammars) {
    my $p = Parse::RLRD::Rule->new($grammar);
    ok(ref $p eq 'Parse::RLRD::Rule', $name);
}

foreach my $test (@tests) {
    my $got = Parse::RLRD::Rule->new($test->{grammar})->apply(Parse::RLRD::Node->new, $test->{data});
    #use Data::Dumper;
    #warn Dumper($got->as_struct);
    is_deeply($got->as_struct, $test->{expected}, $test->{test_name});
}

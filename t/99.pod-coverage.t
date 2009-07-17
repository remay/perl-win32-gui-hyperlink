#!perl -T
# Check the POD covers all method calls:  ignore constants with form ABC_DEF()
# $Id: 99.pod-coverage.t,v 1.3 2005/04/24 17:29:07 Robert May Exp $
use strict;
use warnings;

use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
all_pod_coverage_ok( { also_private => [ qr/^[A-Z_]*/, ] } );

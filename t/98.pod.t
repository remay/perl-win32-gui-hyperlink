#!perl -T
# Syntax check the POD documentation
# $Id: 98.pod.t,v 1.3 2005/04/24 17:29:07 Robert May Exp $
use strict;
use warnings;

use Test::More;
eval "use Test::Pod 1.14";
plan skip_all => "Test::Pod 1.14 required for testing POD" if $@;
all_pod_files_ok();

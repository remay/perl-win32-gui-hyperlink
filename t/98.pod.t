#!perl -T
# Syntax check the POD documentation
# $Id: 98.pod.t,v 1.2 2005/03/01 01:31:43 Robert May Exp $

use Test::More;
eval "use Test::Pod 1.14";
plan skip_all => "Test::Pod 1.14 required for testing POD" if $@;
all_pod_files_ok();

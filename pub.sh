#!/bin/sh
 
set -e
V=$(cat VERSION)
echo $V `date +"%Y-%m-%d %H:%M:%S %z"` `git config user.name` '<'`git config user.email`'>' >> CHANGES.new
echo >> CHANGES.new
echo ' -' >> CHANGES.new
echo >> CHANGES.new
cat CHANGES >> CHANGES.new && mv CHANGES.new CHANGES
$EDITOR CHANGES
./bootstrap
make test
make dist
scp *-$V.tar.gz freddie:scratch
ssh freddie 'set -x ;kill $(cat opt/oktdb/oktdb.pid);cd scratch; tar xf oktdb-'$V'.tar.gz; cd oktdb-'$V'; make install;cd ~/opt/oktdb;(./bin/oktdb.pl prefork --listen http://*:38433 --pid-file=oktdb.pid </dev/null 2>&1 >oktdb.log &)'

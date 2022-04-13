#!/bin/sh
set -e
V=$(cat VERSION)
echo $V $(date +"%Y-%m-%d %H:%M:%S %z") $(git config user.name) '<'$(git config user.email)'>' >> CHANGES.new
echo >> CHANGES.new
echo ' -' >> CHANGES.new
echo >> CHANGES.new
cat CHANGES >> CHANGES.new && mv CHANGES.new CHANGES
$EDITOR CHANGES
./bootstrap
make dist
cat oktdb-$V.tar.gz | ssh kabarett@freddielx 'tar zxf -;cd oktdb-'$V';./configure --prefix=$HOME/opt/oktdb;make install;$HOME/start-oktdb.sh'
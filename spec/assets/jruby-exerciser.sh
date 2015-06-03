#!/bin/sh
set +e

current_dir=`pwd`

wget https://pivotal-buildpacks.s3.amazonaws.com/ruby/binaries/cflinuxfs2/openjdk1.8-latest.tar.gz
mkdir openjdk
tar xzf openjdk1.8-latest.tar.gz -C openjdk
export PATH=$current_dir/openjdk/bin:$PATH

mkdir binary-exerciser
cd binary-exerciser

tar xzf $current_dir/jruby-ruby-2.2.0-jruby-9.0.0.0.pre1-linux-x64.tgz
./bin/jruby -e 'puts "#{RUBY_PLATFORM} #{RUBY_VERSION}"'
#!/usr/bin/env ruby

require 'pathname'
NIGHTLY_BUILD_DIR = Pathname.new(ENV["NIGHTLY_BUILD_DIR"])
BUILD_SCRIPT      = NIGHTLY_BUILD_DIR.join("../build.rb")
CLEANUP_SCRIPT    = NIGHTLY_BUILD_DIR.join("cleanup.sh")

Dir.chdir(NIGHTLY_BUILD_DIR.join("../..")) do
  log = "/tmp/nightly_#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}.log"
  `#{CLEANUP_SCRIPT}            >> #{log} 2>&1`
  `git reset --hard             >> #{log} 2>&1`
  `git clean -dxf               >> #{log} 2>&1`
  `git pull                     >> #{log} 2>&1`
  `ruby #{BUILD_SCRIPT} nightly >> #{log} 2>&1`
end

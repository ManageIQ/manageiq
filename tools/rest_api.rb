#! /usr/bin/env ruby
Dir.chdir(File.join(__dir__, "..")) { require 'bundler/setup' }
require 'pathname'

gem_dir = Pathname.new(Bundler.locked_gems.specs.select { |g| g.name == "manageiq-api" }.first.gem_dir)
load gem_dir.join('exe', 'manageiq-api')

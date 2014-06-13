#!/usr/bin/env ruby
require 'rubygems'
require 'rufus-scheduler'
require 'pathname'

NIGHTLY_BUILD_DIR = Pathname.new(ENV["NIGHTLY_BUILD_DIR"])

scheduler = Rufus::Scheduler.new
scheduler.cron '0 20 * * 1-5' do
  `ruby #{NIGHTLY_BUILD_DIR.join("nightly.rb")}`
end

scheduler.join

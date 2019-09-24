#!/usr/bin/env ruby
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])

# usage: ruby fix_auth -h
#
# upgrades database password columns to v2 passwords
# Alternatively, it will change all passwords to a known one with option -P

if __FILE__ == $PROGRAM_NAME
  $LOAD_PATH.push(File.expand_path(__dir__))
  $LOAD_PATH.push(File.expand_path(File.join(__dir__, %w(.. lib))))
end

require 'active_support/all'
require 'active_support/concern'
# this gets around a bug if a user mistakingly
# serializes a drb object into a configuration hash
require 'drb'
require_relative '../lib/vmdb/settings_walker'
require 'fix_auth/auth_model'
require 'fix_auth/auth_config_model'
require 'fix_auth/models'
require 'fix_auth/cli'
require 'fix_auth/fix_auth'

FixAuth::Cli.run(ARGV, ENV) if __FILE__ == $PROGRAM_NAME

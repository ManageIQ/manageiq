#!/usr/bin/env ruby

# usage: ruby fix_auth -h
#
# upgrades database password columns to v2 passwords
# Alternatively, it will change all passwords to a known one with option -P

if __FILE__ == $PROGRAM_NAME
  $LOAD_PATH.push(File.expand_path(__dir__))
  $LOAD_PATH.push(File.expand_path(File.join(__dir__, %w(.. lib))))
  $LOAD_PATH.push(File.expand_path(File.join(__dir__, %w(.. gems pending))))
end

require File.expand_path('../../config/environment', __FILE__)

require 'active_support/all'
require 'active_support/concern'
require 'fix_auth/auth_model'
require 'fix_auth/auth_config_model'
require 'fix_auth/models'
require 'fix_auth/cli'
require 'fix_auth/fix_auth'

FixAuth::Cli.run(ARGV, ENV) if __FILE__ == $PROGRAM_NAME

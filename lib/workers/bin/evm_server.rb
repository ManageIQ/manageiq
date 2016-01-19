#!/usr/bin/env ruby

if !defined?(MiqEnvironment) || !MiqEnvironment::Process.is_rails_runner?
  require File.expand_path('../../../../config/environment', __FILE__)
end

require "workers/evm_server"
EvmServer.start(*ARGV)

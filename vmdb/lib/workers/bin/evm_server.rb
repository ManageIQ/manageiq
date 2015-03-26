#!/usr/bin/env ruby script/runner

require "workers/evm_server"
EvmServer.start(*ARGV) if MiqEnvironment::Process.is_rails_runner?

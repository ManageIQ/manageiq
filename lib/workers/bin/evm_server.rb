require "workers/evm_server"
if MiqEnvironment::Process.is_rails_runner?
  EvmServer.start(*ARGV)
else
  puts "run with rails runner evm_server.rb"
  exit 1
end

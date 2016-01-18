if defined?(Vmdb::Application) && Vmdb::Application.initialized?
  require "workers/evm_server"
  EvmServer.start(*ARGV)
else
  puts "run with rails runner evm_server.rb"
  exit 1
end

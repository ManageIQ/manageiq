$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'MiqVimBroker'

Connections = [
	{ :server => '', :user => '', :passwd => '' },
]

begin
    broker = MiqVimBroker.new(:client)
	if !broker.serverAlive?
		puts "Broker server isn't running"
		exit
	end

	Connections.each do |c|
    	vim = broker.getMiqVim(c[:server], c[:user], c[:passwd])
	    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
	    puts "API version: #{vim.apiVersion}"
	    puts
	end
	
	loop do
		broker.logStatus
		sleep 120
	end
	
rescue => err
    puts err
	puts err.class.to_s
    puts err.backtrace.join("\n")
end

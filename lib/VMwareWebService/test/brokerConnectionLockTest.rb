$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'MiqVimBroker'

NTHREAD	= 40

CONNECTIONS = [
	#GOAL is to have a couple of these
	{ :server => '',	:user => '',	:password => '' }
]

def openConn(cid)
	Thread.new do
		puts "#{Time.now} - Thread: #{Thread.current.object_id} - connection #{CONNECTIONS[cid][:server]} open - start"
		Thread.current[:t0]		= Time.now
		Thread.current[:vim]	= $broker.getMiqVim(CONNECTIONS[cid][:server], CONNECTIONS[cid][:user], CONNECTIONS[cid][:password])
		Thread.current[:t1]		= Time.now
		puts "#{Time.now} - Thread: #{Thread.current.object_id} - connection #{CONNECTIONS[cid][:server]} open, dt = #{Thread.current[:t1]-Thread.current[:t0]}"
		puts
	end
end

def removeConn(cid)
	Thread.new do
		puts "#{Time.now} - Thread: #{Thread.current.object_id} - connection #{CONNECTIONS[cid][:server]} remove - start"
		Thread.current[:t0]		= Time.now
		Thread.current[:vim]	= $broker.removeMiqVim(CONNECTIONS[cid][:server], CONNECTIONS[cid][:user])
		Thread.current[:t1]		= Time.now
		puts "#{Time.now} - Thread: #{Thread.current.object_id} - connection #{CONNECTIONS[cid][:server]} remove, dt = #{Thread.current[:t1]-Thread.current[:t0]}"
		puts
	end
end

def failConn(cid)
	Thread.new do
		puts "#{Time.now} - Thread: #{Thread.current.object_id} - connection #{CONNECTIONS[cid][:server]} force fail - start"
		Thread.current[:vim] = $broker.getMiqVim(CONNECTIONS[cid][:server], CONNECTIONS[cid][:user], CONNECTIONS[cid][:password])
		Thread.current[:vim].forceFail
		puts "#{Time.now} - Thread: #{Thread.current.object_id} - connection #{CONNECTIONS[cid][:server]} force fail"
		puts
	end
end

begin
    $broker = MiqVimBroker.new(:client)
	if !$broker.serverAlive?
		puts "Broker server isn't running"
		exit
	end
	
	srand Time.now.to_i

	begin
		ta = []
		loop do
			[ 0..NTHREAD ].each do |i|
				cidx = rand(CONNECTIONS.length)
		
				case rand(8)
				when 7
					ta << failConn(cidx)
				when 6
					ta << removeConn(cidx)
				when 5
					ta << removeConn(cidx)
				else
					ta << openConn(cidx)
				end
				Thread.pass
			end
			ta.each { |t| t.join if t.alive? }
			ta.clear
		end
	rescue ThreadError => terr
		retry
	end

rescue => err
    puts err
	puts err.class.to_s
    puts err.backtrace.join("\n")
end


$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'MiqVimBroker'

MAX_CLIENT        = 6
BROKER_SERVER     = "MiqVimBrokerServer.rb"
BROKER_SERVER_LOG = "./broker.log"
BROKER_SERVER_CMD = "ruby #{BROKER_SERVER} > #{BROKER_SERVER_LOG} 2>&1 &"

TESTS = [
	"MiqVimBrokerClient.rb",
  "browserTest.rb",
  "brokerObjCountTest.rb",
  "logTest.rb",
  "virtualDiskPerf.rb",
  "virtualApp.rb",
  "selectionSpecVimTest.rb",
	"MiqVimPerfTest.rb"
]

ERROR_STRINGS = [
  "VimSyncDebug - Locking Thread has terminated:",
  "VimSyncDebug - Lock timeout:",
  "VimSyncDebug - Watchdog ERROR:"
]

def client_count()
  `ps -o command | grep ".rb" | wc -l`.to_i - 4
end

def get_broker_pid
  rva = `ps -Ao pid,command | grep #{BROKER_SERVER}`.split("\n")
  ri = rva.find_index { |ai|  ai["ruby #{BROKER_SERVER}"] }
  raise "Could not determine server's PID." unless ri
  return rva[ri].split(" ")[0]
end

def error_count(str="ERROR")
  `grep "#{str}" #{BROKER_SERVER_LOG} | wc -l`.to_i
end

def print_errors
  ERROR_STRINGS.each do |estr|
    if (c = error_count(estr)) > 0
      puts "\t\t#{estr} #{c}"
    end
  end
end

run            = true
broker_pid     = nil

trap(:INT) do
  puts "#{$0}: Shutting down..."
  run = false
end

#
# Start the VIM broker server.
#
begin

  if `ps -Ao command | grep #{BROKER_SERVER} | wc -l`.to_i <= 2
    system(BROKER_SERVER_CMD)
    raise "*** Command \"#{BROKER_SERVER_CMD}\" failed: status = #{$?.exitstatus}" unless $? == 0
    broker_pid = get_broker_pid
    puts "VIM broker started: PID = #{broker_pid}"
    sleep 5
  else
    #
    # If the broker is already running, use that instance.
    #
    puts "Broker server \"#{BROKER_SERVER}\" already running."
  end

rescue => err
  $stderr.puts "Could not start the VIM broker: #{BROKER_SERVER}"
  puts err.to_s
  exit(1)
end

begin

  broker = MiqVimBroker.new(:client)
  if !broker.serverAlive?
    puts "Broker server isn't running"
    exit(1)
  end
  
  srand Time.now.to_i

  while run
    ec = error_count
    print "#{Time.now.to_s} - Clients: #{client_count} [ERRORS = #{ec}]"
    if client_count < MAX_CLIENT
      cmd = TESTS[rand(TESTS.length)]
      puts "\t** Starting: #{cmd}"
      `ruby #{cmd} > /dev/null 2>&1 &`
    else
      puts "\t** Waiting..."
    end
    print_errors if ec > 0
    sleep 1
  end

  #
  # Kill the broker, only if we started it.
  #
  puts
  if broker_pid
    puts "Killing VIM broker server #{BROKER_SERVER}: PID = #{broker_pid}"
    system("kill -9 #{broker_pid}")
  else
    puts "Pre-existing broker instance continuing to run."
  end

  exit(0)

rescue => err
  puts err.to_s
  puts err.class.to_s
  puts err.backtrace.join("\n")
  exit(1)
end

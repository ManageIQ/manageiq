# encoding: utf-8

module Enumerable
  def mean
    reduce(:+) / length.to_f
  end

  def stddev
    mean = self.mean
    Math.sqrt(inject(0) { |sum, i| sum + (i - mean) ** 2 } / length.to_f)
  end
end

require_relative '../../bundler_setup'

$:.push("#{File.dirname(__FILE__)}/..")
require 'MiqVimBroker'

require 'benchmark'
require_relative '../../util/miq-process'

SERVER_PROCESS = "ruby #{File.join(File.dirname(__FILE__), "MiqVimBrokerServer.rb")}"
SERVER_PASSES = 10
CLIENT_PASSES = 5

def with_server
  pid = Kernel.spawn(SERVER_PROCESS, :out => "/dev/null", :err => "/dev/null")
  Process.detach(pid)
  sleep(2) # Give the server a chance to actually start up
  yield pid
ensure
  Process.kill("HUP", pid) # Because the script blocks INT for some reason
end

def connect_client
  broker = MiqVimBroker.new(:client)
  broker.getMiqVim(SERVER, USERNAME, PASSWORD)
end

all_stats = SERVER_PASSES.times.collect do |t|
  print "Pass #{t + 1}/#{SERVER_PASSES}... "

  stats = with_server do |pid|
    CLIENT_PASSES.times.collect do |i|
      {
        # On the first pass, don't connect, just get memory statistics
        :time   => i == 0 ? 0.0 : Benchmark.realtime { connect_client },
        :memory => MiqProcess.processInfo(pid)[:memory_usage] / 1024.0 / 1024.0
      }
    end
  end

  puts stats.collect { |s| "#{s[:time].round(4)}s #{s[:memory].round(2)}M" }.join(" | ")
  stats
end

def print_stats(stats)
  timings = stats.collect { |s| s[:time] }
  memory  = stats.collect { |s| s[:memory] }

  values = [
    "#{timings.mean.round(4)}s ± #{timings.stddev.round(4)}s",
    "#{memory.mean.round(2)}M ± #{memory.stddev.round(2)}M",
  ]

  values.join(" | ")
end

transposed  = all_stats.transpose
before      = transposed[0]
unprimed    = transposed[1]
primed_once = transposed[2]
primed_rest = transposed[3..-1].flatten

puts
puts "                 | Timing | Memory |"
puts "---------------- | ------ | ------ |"
puts "Before connect   | #{print_stats(before)} | "
puts "Unprimed (first) | #{print_stats(unprimed)} | "
puts "Primed (second)  | #{print_stats(primed_once)} | "
puts "Primed (rest)    | #{print_stats(primed_rest)} | "

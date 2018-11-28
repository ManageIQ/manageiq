#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

require 'optimist'
ARGV.shift if ARGV.first == "--" # Handle when called through script/runner
opts = Optimist.options do
  opt :ip,     "IP address", :type => :string, :required => true
  opt :user,   "User Name",  :type => :string, :required => true
  opt :pass,   "Password",   :type => :string, :required => true

  opt :bypass, "Bypass broker usage", :type => :boolean
  opt :dir,    "Output directory",    :default => "."
end
Optimist.die :ip, "is an invalid format" unless opts[:ip] =~ /^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}$/

targets = eval(ARGV.first) rescue nil
if targets.nil? || !targets.kind_of?(Array) || targets.empty?
  puts "Validation Errors:"
  puts "  First argument must be an eval-able array of arrays of"
  puts "    target, interval name, start_time, end_time"
  puts "  Target must be a MOR, or a class/id pair in the format 'Class:id'"
  puts "  Example: \"[['Vm:10', 'realtime', nil, nil]]\""
  exit 1
end
targets = [targets] unless targets.first.kind_of?(Array)

targets.each do |t|
  # Adjust the first argument to be a MOR
  if t[0].include?(':')
    klass, id = t[0].split(':')
    t[0] = Object.const_get(klass).find(id).ems_ref_obj
  else
    mor = t[0]
    vim_type = case mor
               when /^vm-/      then "VirtualMachine"
               when /^host-/    then "HostSystem"
               when /^cluster-/ then "ClusterComputerResource"
               else
                 puts "Validation Errors:"
                 puts "  target must be a valid MOR"
                 exit 1
               end

    t[0] = VimString.new(mor, vim_type, "ManagedObjectReference")
  end

  # Adjust the second argument to be a perf interval
  t[1] = case t[1]
         when "realtime" then "20"
         when "hourly"   then "7200"
         else
           puts "Validation Errors:"
           puts "  unknown interval '#{t[1]}'"
           exit 1
         end
end
mors = targets.collect { |t| t[0] }.uniq

def process(accessor, dir)
  puts "Reading #{accessor}..."
  data = yield
  puts "Writing #{accessor}..."
  File.open(File.join(dir, "#{accessor}.yml"), "w") { |f| f.write(data.to_yaml(:SortKeys => true)) }
  data
end

dir = File.expand_path(File.join(opts[:dir], "miq_vim_perf_history"))
Dir.mkdir(dir) unless File.directory?(dir)
puts "Output in #{dir}"

begin
  require 'VMwareWebService/miq_fault_tolerant_vim'
  vim = MiqFaultTolerantVim.new(
    :ip                  => opts[:ip],
    :user                => opts[:user],
    :pass                => opts[:pass],
    :use_broker          => !opts[:bypass],
    :vim_broker_drb_port => MiqVimBrokerWorker.drb_port
  )

  ph = vim.getVimPerfHistory

  a = :intervals
  process(a, dir) { ph.send(a) }

  a = :id2Counter
  process(a, dir) { ph.send(a) }

  a = :queryProviderSummary
  process(a, dir) do
    mors.each_with_object({}) do |mor, data|
      puts "Reading #{a} for #{mor.inspect}..."
      data.store_path(mor, ph.send(a, mor))
    end
  end

  a = :availMetricsForEntity
  metrics_data = process(a, dir) do
    targets.each_with_object({}) do |(mor, interval, _start_time, _end_time), data|
      puts "Reading #{a} for #{mor.inspect}, #{interval.inspect}..."
      data.store_path(mor, interval, ph.send(a, mor, :intervalId => interval))
    end
  end

  a = :queryPerfMulti
  process(a, dir) do
    targets.each_with_object({}) do |(mor, interval, start_time, end_time), data|
      query = [{
        :entity     => mor,
        :intervalId => interval,
        :startTime  => start_time,
        :endTime    => end_time,
        :metricId   => metrics_data.fetch_path(mor, interval).collect { |m| {:counterId => m["counterId"], :instance => m["instance"]} }
      }]

      puts "Reading #{a} for #{mor.inspect}, #{interval.inspect}, #{start_time.inspect}, #{end_time.inspect}..."
      data.store_path(mor, interval, start_time, end_time, ph.send(a, query))
    end
  end
ensure
  ph.release  unless ph.nil?  rescue nil
  vim.release unless vim.nil? rescue nil
end

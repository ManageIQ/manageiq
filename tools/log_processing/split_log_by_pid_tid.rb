#!/usr/bin/env ruby

RAILS_ROOT = File.expand_path(File.join(__dir__, %w(.. ..)))
require 'manageiq-gems-pending'
require 'miq_logger_processor'

logfile = ARGV.shift if ARGV[0] && File.file?(ARGV[0])
logfile ||= File.join(RAILS_ROOT, "log/evm.log")
logfile = File.expand_path(logfile)

outdir = ARGV.shift if ARGV[0] && File.directory?(ARGV[0])
outdir ||= "#{File.dirname(logfile)}/split_by_pid_tid"
outdir.chomp!("/")
outdir.chomp!("\\")
outdir = File.expand_path(outdir)

require 'fileutils'
FileUtils.mkpath(outdir)

t = Time.now
puts "Splitting files..."

pidtid_to_file = {}
pidtid_to_info = Hash.new { |h, k| h[k] = {} }

MiqLoggerProcessor.new(logfile).each do |line|
  pidtid = "#{line.pid}-#{line.tid}"

  begin
    outfile = (pidtid_to_file[pidtid] ||= File.new("#{outdir}/#{pidtid}.log", "w"))
    outfile = (pidtid_to_file[pidtid]   = File.new("#{outdir}/#{pidtid}.log", "a")) if outfile.closed?
  rescue Errno::EMFILE
    # Out of file handles. Closing and trying again.
    pidtid_to_file.values.each { |f| f.close unless f.closed? }
    retry
  end

  outfile.write(line)

  info = pidtid_to_info[pidtid]
  info[:name] = $1 if !info.key?(:name) && (line.message =~ /^MIQ\(([A-Za-z]+Worker(?=\))|EventCatcher(?=\))|(?:Ems)?EventHandler(?=\))|WorkerMonitor|Server(?=\.))/ || line.message =~ /^<(VIM|AutomationEngine)>/)
  info[:time] = line.time unless info.key?(:time)
end

pidtid_to_file.values.each { |f| f.close unless f.closed? }

puts "Splitting files...Complete (#{Time.now - t}s)"

puts "Renaming known workers..."

pidtid_to_info.each do |pidtid, info|
  name = info[:name] ? "#{info[:name]}-" : ""
  time = info[:time] ? "#{info[:time].delete('-:.')}-" : ""
  File.rename("#{outdir}/#{pidtid}.log", "#{outdir}/#{name}#{time}#{pidtid}.log")
end

puts "Renaming known workers...Complete"

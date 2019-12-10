#!/usr/bin/env ruby

if ARGV.empty?
  puts "USAGE: #{__FILE__} job_class [outfile]"
  exit 1
end

job_class, outfile = ARGV

require File.expand_path("../config/environment", __dir__)

job_class = job_class.constantize rescue NilClass
unless job_class < Job
  puts "ERROR: job_class is not a subclass of Job.\n\nValid job_class values are:"
  puts Job.descendants.map(&:name).sort.join("\n").indent(2)
  exit 1
end

outfile ||= "#{job_class.name.underscore.tr("/", "-")}.svg"
File.write(outfile, job_class.to_svg)
puts "\nWritten to #{outfile}"

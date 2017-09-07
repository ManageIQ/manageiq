#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

output = ARGV[0]
raise "No output file provided" if output.nil?

puts "Exporting classification tags..."
File.open(output, "w") { |f| f.write(Classification.export_to_yaml) }
puts "Exporting classification tags... Complete"

#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'optimist'

options = Optimist.options do
  opt :userid, "userid for imported schedule(this option overwrites schedule's userid)", :short => "u", :type => :string
  opt :output_dir, "Output directory", :short => "d", :default => "./"
  opt :schedule, "Schedule name or id", :short => "s", :type => :string
  opt :operation, "export or import", :short => "o", :default => "export"
  opt :import_yaml, "imported yaml", :short => "y", :type => :io
end

def schedule_from_args(schedule)
  if is_numeric?(schedule)
    MiqSchedule.find_by(:id => schedule)
  else
    MiqSchedule.find_by(:name => schedule)
  end
end

case options[:operation]
when 'export'
  schedule = schedule_from_args(options[:schedule])
  Optimist.die "Schedule #{options[:schedule]} doesn't exist" if schedule.nil?

  Optimist.die "Output dir #{options[:output_dir]} doesn't exist" unless File.directory?(options[:output_dir])

  exported_yaml = MiqSchedule.export_to_yaml([schedule], MiqSchedule)

  output_path = File.join(options[:output_dir], "#{schedule.resource_type}_#{Time.now.to_i}.yaml")
  puts "Schedule #{schedule.name} exported to #{output_path}"
  File.write(output_path, exported_yaml)
when 'import'
  result = MiqSchedule.import(options[:import_yaml], options)
  puts result.second[0][:message]
end

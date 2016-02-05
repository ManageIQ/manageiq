RAILS_ROOT = ENV["RAILS_ENV"] ? Rails.root : File.expand_path(File.join(__dir__, %w(.. ..)))
$:.push File.join(RAILS_ROOT, "gems/pending/util") unless ENV["RAILS_ENV"]

require 'miq_logger_processor'
require 'time'

TARGETS = [ "EmsVmware" , "HostVmwareEsx", "VmVmware" ]
COLUMNS = ["start", "end", "duration", "ems", "target"]

logfiles = ARGV.select { |f| File.file?(f) }
logfiles << File.join(RAILS_ROOT, "log/evm.log") if logfiles.empty?
logfiles.map { |f| File.expand_path(f) }

puts "Processing file..."

all_timings = []
ems_timings = Hash.new { |k, v| k[v] = [] }
all_targets = Hash.new { |k, v| k[v] = [] }

logfiles.each do |logfile|
  MiqLoggerProcessor.new(logfile).each do |line|
    # Find the target type
    if line =~ /MIQ\(VcRefresher.refresh\).EMS:? \[(.*?)\].+Refreshing target ([^\s]+).+Complete/
      ems         = $1
      target_type = $2

      all_targets[ems] << {
        :time        => line.time,
        :target_type => target_type
      }
    end

    next unless line =~ /MIQ\(VcRefresher.refresh\).EMS:? \[(.*?)\].+Timings:? (\{.+)$/
    ems     = $1
    timings = eval($2)

    timings[:end_time]    = Time.parse(line.time + " UTC")
    timings[:start_time]  = timings[:end_time] - timings[:total_time]
    timings[:target_type] = all_targets[ems].last[:target_type]
    timings[:ems]         = ems

    if TARGETS.include?(timings[:target_type])
      all_timings      << timings
      ems_timings[ems] << timings
    end
  end
end

print "Found #{all_timings.length} refreshes from #{ems_timings.keys.length} providers\n"

COLUMN_MAX_LENGTH = [ 0, 0, 0, 0, 0]
all_timings.sort_by { |t| t[:start_time] }.each do |timing|
  COLUMN_MAX_LENGTH[0] = [COLUMN_MAX_LENGTH[0], timing[:start_time].to_s.length].max
  COLUMN_MAX_LENGTH[1] = [COLUMN_MAX_LENGTH[1], timing[:end_time].to_s.length].max
  COLUMN_MAX_LENGTH[2] = [COLUMN_MAX_LENGTH[2], timing[:total_time].to_s.length].max
  COLUMN_MAX_LENGTH[3] = [COLUMN_MAX_LENGTH[3], timing[:ems].length].max
  COLUMN_MAX_LENGTH[4] = [COLUMN_MAX_LENGTH[4], timing[:target_type].length].max
end

COLUMNS.each_with_index do |col, i|
  print "#{col.ljust(COLUMN_MAX_LENGTH[i])}   "
end
print "\n"

all_timings.sort_by { |t| t[:start_time] }.each do |timing|
  print "#{timing[:start_time].to_s.ljust(COLUMN_MAX_LENGTH[0])} | #{timing[:end_time].to_s.ljust(COLUMN_MAX_LENGTH[1])} | #{timing[:total_time].to_s.ljust(COLUMN_MAX_LENGTH[2])} | #{timing[:ems].to_s.ljust(COLUMN_MAX_LENGTH[3])} | #{timing[:target_type].to_s.ljust(COLUMN_MAX_LENGTH[4])}\n"
end

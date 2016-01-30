# Needs to be run with script/runner
#

def syntax
  puts "Syntax: #{$0} filename_to_import"
  exit 0
end

def import_file(fname)
  puts "Import Beginning for #{fname}"

  unless File.exist?(fname)
    puts "Specified file does not exist"
    return
  end

  File.open(fname) do |fd|
    stats = Policy.import_from_yaml(fd)
    puts "Import Completed for #{fname} (added #{stats["Policy"]} policies, #{stats["MiqEventDefinition"]} events, #{stats["Condition"]} conditions, #{stats["MiqAction"]} actions)"

    $gstats["npolicies"] += stats["Policy"]
    $gstats["nevents"] += stats["MiqEventDefinition"]
    $gstats["nactions"] += stats["MiqAction"]
    $gstats["nconditions"] += stats["Condition"]
  end
end

$gstats = {"nactions" => 0, "nconditions" => 0, "nevents" => 0, "npolicies" => 0}
syntax if ARGV.length == 0
ARGV.each { |fname| import_file(fname) }
puts "Import Completed"
puts "\tNew Events:     #{$gstats["nevents"]}"
puts "\tNew Conditions: #{$gstats["nconditions"]}"
puts "\tNew Actions:    #{$gstats["nactions"]}"
puts "\tNew Policies:   #{$gstats["npolicies"]}"

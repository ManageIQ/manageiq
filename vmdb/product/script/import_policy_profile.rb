# Needs to be run with script/runner
#

# Load the Policy Class so that we get PolicySet defined
begin
  p1 = Policy.find(1)
rescue
end


def syntax
  puts "Syntax: #{$0} filename_to_import"
  exit 0
end

def import_file(fname)
  puts "Import Beginning for #{fname}"

  if !File.exist?(fname)
    puts "Specified file does not exist"
    return
  end

  File.open(fname) { |fd|
    stats = PolicySet.import_from_yaml(fd)
    puts "Import Completed for #{fname} (added #{stats["PolicySet"]} profiles, #{stats["Policy"]} policies, #{stats["MiqEvent"]} events, #{stats["Condition"]} conditions, #{stats["MiqAction"]} actions)"

    $gstats["nprofiles"]   += stats["PolicySet"]
    $gstats["npolicies"]   += stats["Policy"]
    $gstats["nevents"]     += stats["MiqEvent"]
    $gstats["nactions"]    += stats["MiqAction"]
    $gstats["nconditions"] += stats["Condition"]
  }
end

$gstats = { "nactions" => 0, "nconditions" => 0, "nevents" => 0, "npolicies" => 0, "nprofiles" => 0}
syntax if ARGV.length == 0
ARGV.each { |fname| import_file(fname) }
puts "Import Completed"
puts "\tNew Events:     #{$gstats["nevents"]}"
puts "\tNew Conditions: #{$gstats["nconditions"]}"
puts "\tNew Actions:    #{$gstats["nactions"]}"
puts "\tNew Policies:   #{$gstats["npolicies"]}"
puts "\tNew Profiles:   #{$gstats["nprofiles"]}"

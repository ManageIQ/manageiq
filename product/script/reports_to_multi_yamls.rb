# Needs to be run with script/runner
# ruby script/runner product/script/reports_to_multi_yamls.rb filename
# this script can be run to split yaml file with multiple reports into their own yaml files
#

input_file = ARGV[0]

unless File.exist?(input_file)
  puts "File '#{input_file}' does not exist"
  exit 1
end

reports = YAML.load_file(input_file)
puts "File '#{input_file}' contains #{reports.length} reports"

ctr = 0
reports.each do |r|
  ctr += 1
  name = File.join(Dir.pwd, "#{ctr}_#{r["name"]}.yaml")
  File.open(name, "w") { |f| f.write(YAML.dump(r)) }
  puts "Created file '#{name}'"
end

puts "Done"

exit 0

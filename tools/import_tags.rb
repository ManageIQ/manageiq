input = ARGV[0]
raise "No input file provided" if input.nil?

puts "Importing classification tags..."
File.open(input) { |f| Classification.import_from_yaml(f) }
puts "Importing classification tags... Complete"

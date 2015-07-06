require 'trollop'
ARGV.shift if ARGV[0] == '--'
opts = Trollop.options do
  banner "Generate SCVMM test data.\n\nUsage: rails runner #{$PROGRAM_NAME} [-- options]\n\nOptions:\n\t"
  opt :username,  "User Name",  :type => :string
  opt :ipaddress, "IP Address", :type => :string
  opt :port,      "Port",       :type => :integer
end
Trollop.die "username must be passed"  unless opts[:username_given]
Trollop.die "ipaddress must be passed" unless opts[:ipaddress_given]

require 'io/console' if RUBY_VERSION < "2"
STDOUT.write("Password: ")
password = STDIN.noecho(&:gets).chomp
puts

puts "Connecting"
win_rm = EmsMicrosoft.raw_connect(
  opts[:username],
  password,
  EmsMicrosoft.auth_url(opts[:ipaddress], opts[:port])
)

puts "Collecting"
data = File.open(EmsRefresh::Parsers::Scvmm::INVENTORY_SCRIPT, "r") do |f|
  win_rm.run_powershell_script(f)
end

# Convert values to US-ASCII binary for yml readability
data[:data].each do |datum|
  datum.keys.each do |k|
    v = datum[k]
    datum[k] = v.force_encoding("US-ASCII") if v.ascii_only?
  end
end

output_yml  = File.expand_path(File.join(File.dirname(__FILE__), "get_inventory_output.yml"))
output_xml  = File.expand_path(File.join(File.dirname(__FILE__), "get_inventory_output.xml"))
output_hash = File.expand_path(File.join(File.dirname(__FILE__), "get_inventory_output_hash.yml"))

puts "Writing yml"
File.write(output_yml, data.to_yaml)

puts "Writing xml"
File.write(output_xml, EmsMicrosoft.powershell_results_to_xml(data))

puts "Writing hash"
File.write(output_hash, EmsMicrosoft.powershell_results_to_hash(data).to_yaml)

puts "Complete"

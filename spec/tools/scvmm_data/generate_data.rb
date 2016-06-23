require 'trollop'
require 'io/console'

ARGV.shift if ARGV[0] == '--'

opts = Trollop.options do
  banner "Generate SCVMM test data.\n\nUsage: rails runner #{$PROGRAM_NAME} [-- options]\n\nOptions:\n\t"
  opt :username,  "User Name",  :type => :string
  opt :hostname,  "IP Address", :type => :string
  opt :port,      "Port",       :type => :integer, :default => 5985
end

Trollop.die "username must be passed" unless opts[:username_given]
Trollop.die "hostname must be passed" unless opts[:hostname]

STDOUT.write("Password: ")
password = STDIN.noecho(&:gets).chomp
puts

puts "Using the following information:"
puts "Hostname: " + opts[:hostname]
puts "Username: " + opts[:username]
puts "Port: "     + opts[:port].to_s

puts "Connecting"
win_rm = ManageIQ::Providers::Microsoft::InfraManager.raw_connect(
  ManageIQ::Providers::Microsoft::InfraManager.auth_url(opts[:hostname], opts[:port]),
  "ssl",
  :user => opts[:username],
  :pass => password
)

puts "Collecting"

data = ManageIQ::Providers::Microsoft::InfraManager.execute_powershell(win_rm, ManageIQ::Providers::Microsoft::InfraManager::RefreshParser::INVENTORY_SCRIPT)

output_yml  = File.expand_path(File.join(File.dirname(__FILE__), "get_inventory_output.yml"))
output_hash = File.expand_path(File.join(File.dirname(__FILE__), "get_inventory_output_hash.yml"))

puts "Writing yml"
File.write(output_yml, data.to_yaml)

puts "Complete"

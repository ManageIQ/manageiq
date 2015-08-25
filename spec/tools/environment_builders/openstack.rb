require 'fog'
# TODO(lsmola) how do I load this?
# require 'models/ems_refresh/refreshers/openstack/refresh_spec_environments'

$LOAD_PATH.push(Rails.root.to_s)
require_relative 'openstack/interaction_methods'

require_relative 'openstack/services/identity/builder'
require_relative 'openstack/services/network/builder'
require_relative 'openstack/services/compute/builder'
require_relative 'openstack/services/volume/builder'
require_relative 'openstack/services/image/builder'

include InteractionMethods

def usage(s)
  $stderr.puts(s)
  $stderr.puts("Run on a VM with at least 8GB of RAM!!!")
  $stderr.puts("Usage: bundle exec rails r spec/tools/environment_builders/openstack.rb <ems_id>")
  $stderr.puts("Options:")
  $stderr.puts("         [--networking <netwoking>]  - allowed values [nova, neutron], default => neutron")
  $stderr.puts("         [--identity   <identity>]   - allowed values [v2, v3],        default => v2")
  exit(2)
end

@ems_id = ARGV.shift
raise ArgumentError, usage("expecting ExtManagementSystem id as a first argument") if @ems_id.blank?
@networking = :neutron
@identity   = :v2

loop do
  option = ARGV.shift
  case option
  when '--networking'
    argv      = ARGV.shift
    supported = %w(neutron nova)
    raise ArgumentError, usage("supported --networking options are #{supported}") unless supported.include?(argv)
    @networking = argv.to_sym
  when '--identity'
    argv      = ARGV.shift
    supported = %w(v2 v3)
    raise ArgumentError, usage("supported --identity options are #{supported}") unless supported.include?(argv)
    @identity = argv.to_sym
  when /^-/
    usage("Unknown option: #{option}")
  else
    break
  end
end

$fog_log.level = 0
puts "Building Refresh Environment for networking: '#{@networking}' and keystone: '#{@identity}'..."

@ems = ManageIQ::Providers::Openstack::CloudManager.where(:id => @ems_id).first

# TODO: Create a domain to contain refresh-related objects (Havana and above)
identity = Openstack::Services::Identity::Builder.build_all(@ems)
# TODO(lsmola) cycle through many projects, so we test also multitenancy
project = identity.projects.detect { |x| x.name == "EmsRefreshSpec-Project" }

network = Openstack::Services::Network::Builder.build_all(@ems, project, @networking)
compute = Openstack::Services::Compute::Builder.build_all(@ems, project)
volume = Openstack::Services::Volume::Builder.build_all(@ems, project)
image = Openstack::Services::Image::Builder.build_all(@ems, project)

#
# Create all servers
#
compute.build_servers(volume, network, image)

#
# Set states of the servers
#
compute.do_action(compute.servers.detect { |x| x.name == "EmsRefreshSpec-Paused" }, :pause)
compute.do_action(compute.servers.detect { |x| x.name == "EmsRefreshSpec-Suspended" }, :suspend)
# TODO(lsmola) do shelve action once we use new fog
# compute.do_action(compute.servers.detect{|x| x.name == "EmsRefreshSpec-Shelved"}, :shelve)

puts "Finished"

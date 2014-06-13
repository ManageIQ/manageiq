require 'fog'
$LOAD_PATH.push(Rails.root.to_s)
require_relative 'openstack/image_methods'
require_relative 'openstack/interaction_methods'
require_relative 'openstack/network_methods'
require_relative 'openstack/setup_methods'

include ImageMethods
include InteractionMethods
include NetworkMethods
include SetupMethods

ARGV.shift if ARGV.first == "--"
@environment = ARGV.first.to_s.downcase
raise ArgumentError, "expecting an environment argument" if @environment.blank?

$fog_log.level = 0
puts "Building Refresh Environment for #{@environment}..."

# Setup outer structure
# TODO: Create a domain to contain refresh-related objects (Havana and above)
# TODO: Create a project and all object should live in that project, possibly.

#
# Setup Network
#
find_or_create_networks
find_or_create_subnet
find_or_create_router
find_or_create_floating_ip

sg = find_or_create(fog.security_groups,
  :name        => "EmsRefreshSpec-SecurityGroup",
  :description => "EmsRefreshSpec-SecurityGroup description"
)

sg2 = find_or_create(fog.security_groups,
  :name        => "EmsRefreshSpec-SecurityGroup2",
  :description => "EmsRefreshSpec-SecurityGroup2 description"
)

find_or_create_firewall_rules(sg)

#
# Setup Flavor
#
flavor = find_or_create(fog.flavors,
  :name      => "m1.ems_refresh_spec",
  :is_public => true,
  :vcpus     => 1,
  :ram       => 1024, # MB
  :disk      => 1, # GB
  :ephemeral => 1, # GB
  :swap      => 512, # MB
)

#
# Setup Keypair
#
kp = find_or_create(fog.key_pairs,
  :name => "EmsRefreshSpec-KeyPair"
)
if kp.private_key
  File.write("EmsRefreshSpec-KeyPair.pem", kp.private_key)
  puts "Your new key_pair private key has been written to 'EmsRefreshSpec-KeyPair.pem'"
end

#
# Setup Volumes
#
vol_type = find(volume_types(fog_volume), :name => "EmsRefreshSpec-VolumeType")
if vol_type.nil?
  # volume types are not createable through the Openstack API
  puts "ERROR: You must manually create a volume type named 'EmsRefreshSpec-VolumeType' before continuing."
  exit 1
end

vol = find_or_create(fog.volumes,
  :name        => "EmsRefreshSpec-Volume",
  :description => "EmsRefreshSpec-Volume description",
  :size        => 1,
  :volume_type => "EmsRefreshSpec-VolumeType"
)

vol_snap = find_or_create(fog.snapshots,
  :name        => "EmsRefreshSpec-VolumeSnapshot",
  :description => "EmsRefreshSpec-VolumeSnapshot description",
  :volume_id   => vol.id
)

find_or_create(fog.volumes,
  :name        => "EmsRefreshSpec-Volume-FromSnapshot",
  :description => "EmsRefreshSpec-Volume-FromSnapshot description",
  :size        => vol_snap.size,
  :snapshot_id => vol_snap.id
)

#
# Setup Images and servers
#
image = find_or_create_image(fog.images,
  :name => "EmsRefreshSpec-Image"
)

server_on_settings = {
  :name                 => "EmsRefreshSpec-PoweredOn",
  :flavor_ref           => flavor.id,
  :image_ref            => image.id,
  :block_device_mapping => {
    :volume_id   => vol.id,
    :device_name => "vda"
  },
  :key_name             => kp.name,
  :security_groups      => [sg.name, sg2.name],
}

server_on_settings[:nics] = [{"net_id" => @network_private.id}] if @network_private

server_on = find_or_create_server(fog.servers, server_on_settings)
puts "Finding {:ip => #{@floating_ip.inspect}} on #{server_on.class.name}"
if server_on.addresses.blank?
  puts "Associating {:ip => #{@floating_ip.inspect}} to #{server_on.class.name}"
  server_on.associate_address(@floating_ip)
end

server_snap = find_or_create_image_from_server(fog.images, server_on,
  :name => "EmsRefreshSpec-Snapshot"
)

server_from_snap_settings = {
  :name            => "EmsRefreshSpec-PoweredOn-FromSnapshot",
  :flavor_ref      => flavor.id,
  :image_ref       => server_snap.id,
  :key_name        => kp.name,
  :security_groups => sg.name,
}

server_from_snap_settings[:nics] = [{"net_id" => @network_private.id}] if @network_private

find_or_create_server(fog.servers, server_from_snap_settings)

server_paused_settings = {
  :name            => "EmsRefreshSpec-Paused",
  :flavor_ref      => flavor.id,
  :image_ref       => image.id,
  :key_name        => kp.name,
  :security_groups => sg.name,
}

server_paused_settings[:nics] = [{"net_id" => @network_private.id}] if @network_private

server_paused = find_or_create_server(fog.servers, server_paused_settings)
if server_paused.state != "PAUSED"
  puts "Pausing server."
  fog.pause_server(server_paused.id)
end

server_suspended_settings = {
  :name            => "EmsRefreshSpec-Suspended",
  :flavor_ref      => flavor.id,
  :image_ref       => image.id,
  :key_name        => kp.name,
  :security_groups => sg.name,
}

server_suspended_settings[:nics] = [{"net_id" => @network_private.id}] if @network_private

server_suspend = find_or_create_server(fog.servers, server_suspended_settings)
if server_suspend.state != "SUSPENDED"
  puts "Suspending server."
  fog.suspend_server(server_suspend.id)
end

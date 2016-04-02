require 'fog/google'

module ManageIQ::Providers
  module Google
    class CloudManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
      include Vmdb::Logging

      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, options = nil)
        @ems               = ems
        @connection        = ems.connect
        @options           = options || {}
        @data              = {}
        @data_index        = {}
        @project_key_pairs = Set.new

        # Mapping from disk url to source image id.
        @disk_to_source_image_id = {}
      end

      def ems_inv_to_hashes
        log_header = "Collecting data for EMS : [#{@ems.name}] id: [#{@ems.id}]"

        _log.info("#{log_header}...")
        get_zones
        get_flavors
        get_cloud_networks
        get_security_groups
        get_volumes
        get_snapshots
        get_images
        get_instances # Must occur after get_volumes is called
        _log.info("#{log_header}...Complete")

        link_volumes_to_base_snapshots

        @data
      end

      private

      def get_zones
        zones = @connection.zones.all
        process_collection(zones, :availability_zones) { |zone| parse_zone(zone) }
      end

      def get_flavors
        # connection.flavors returns a duplicate flavor for every zone
        # so build a unique list of flavors using the flavor id
        flavors = @connection.flavors.to_a.uniq(&:id)
        process_collection(flavors, :flavors) { |flavor| parse_flavor(flavor) }
      end

      def get_cloud_networks
        networks = @connection.networks.all
        process_collection(networks, :cloud_networks) { |network| parse_cloud_network(network) }
      end

      def get_security_groups
        networks = @data[:cloud_networks]
        firewalls = @connection.firewalls.all

        process_collection(networks, :security_groups) do |network|
          sg_firewalls = firewalls.select { |fw| parse_uid_from_url(fw.network) == network[:name] }
          parse_security_group(network, sg_firewalls)
        end
      end

      def get_volumes
        disks = @connection.disks.all
        process_collection(disks, :cloud_volumes) { |volume| parse_volume(volume) }
      end

      def get_snapshots
        snapshots = @connection.snapshots.all
        process_collection(snapshots, :cloud_volume_snapshots) { |snapshot| parse_snapshot(snapshot) }
      end

      def get_images
        images = @connection.images.all
        process_collection(images, :vms) { |image| parse_image(image) }
      end

      def get_key_pairs(instances)
        ssh_keys = []

        # Find all key pairs added directly to GCE instances
        instances.each do |instance|
          ssh_keys |= parse_compute_metadata_ssh_keys(instance.metadata)
        end

        # Add ssh keys that are common to all instances in the project
        project_common_metadata = @connection.projects.get(@ems.project).common_instance_metadata
        @project_key_pairs      = parse_compute_metadata_ssh_keys(project_common_metadata)

        ssh_keys |= @project_key_pairs

        process_collection(ssh_keys, :key_pairs) { |ssh_key| parse_ssh_key(ssh_key) }
      end

      def get_instances
        instances = @connection.servers.all

        # Since SSH keys are stored with the instances this is
        # the only place we can get a complete and unique list
        # of key-pairs
        get_key_pairs(instances)

        process_collection(instances, :vms) { |instance| parse_instance(instance) }
      end

      def process_collection(collection, key)
        @data[key] ||= []

        collection.each do |item|
          uid, new_result = yield(item)
          next if uid.nil?

          @data[key] << new_result
          @data_index.store_path(key, uid, new_result)
        end
      end

      def parse_zone(zone)
        name = uid = zone.name
        type = ManageIQ::Providers::Google::CloudManager::AvailabilityZone.name

        new_result = {
          :type    => type,
          :ems_ref => uid,
          :name    => name,
        }

        return uid, new_result
      end

      def parse_flavor(flavor)
        uid = flavor.name

        type = ManageIQ::Providers::Google::CloudManager::Flavor.name
        new_result = {
          :type        => type,
          :ems_ref     => flavor.name,
          :name        => flavor.name,
          :description => flavor.description,
          :enabled     => !flavor.deprecated,
          :cpus        => flavor.guest_cpus,
          :cpu_cores   => 1,
          :memory      => flavor.memory_mb * 1.megabyte,
        }

        return uid, new_result
      end

      def parse_cloud_network(network)
        uid = network.id

        new_result = {
          :ems_ref => uid,
          :name    => network.name,
          :cidr    => network.ipv4_range,
          :status  => "active",
          :enabled => true,
        }

        return uid, new_result
      end

      def self.security_group_type
        ManageIQ::Providers::Google::CloudManager::SecurityGroup.name
      end

      def parse_security_group(network, firewalls)
        uid            = network[:name]
        firewall_rules = firewalls.collect { |fw| parse_firewall_rules(fw) }.flatten

        new_result = {
          :type           => self.class.security_group_type,
          :ems_ref        => uid,
          :name           => uid,
          :cloud_network  => network,
          :firewall_rules => firewall_rules,
        }

        return uid, new_result
      end

      def parse_firewall_rules(fw)
        ret = []

        name            = fw.name
        source_ip_range = fw.source_ranges.nil? ? "0.0.0.0/0" : fw.source_ranges.first

        fw.allowed.each do |fw_allowed|
          protocol      = fw_allowed["IPProtocol"].upcase
          allowed_ports = fw_allowed["ports"].to_a.first

          unless allowed_ports.nil?
            from_port, to_port = allowed_ports.split("-", 2)
          else
            # The ICMP protocol doesn't have ports so set to -1
            from_port = to_port = -1
          end

          new_result = {
            :name            => name,
            :direction       => "inbound",
            :host_protocol   => protocol,
            :port            => from_port,
            :end_port        => to_port,
            :source_ip_range => source_ip_range
          }

          ret << new_result
        end

        ret
      end

      def parse_volume(volume)
        zone_id = parse_uid_from_url(volume.zone)

        new_result = {
          :ems_ref           => volume.id,
          :name              => volume.name,
          :status            => volume.status,
          :creation_time     => volume.creation_timestamp,
          :volume_type       => parse_uid_from_url(volume.type),
          :description       => volume.description,
          :size              => volume.size_gb.to_i.gigabyte,
          :availability_zone => @data_index.fetch_path(:availability_zones, zone_id),
          # Note that this is just the name, not the hash - this must be
          # rewritten before returning the data to ems
          :base_snapshot     => volume.source_snapshot,
        }

        # Take note of the source_image_id so we can expose it in parse_instance
        @disk_to_source_image_id[volume.self_link] = volume.source_image_id

        return volume.self_link, new_result
      end

      def parse_snapshot(snapshot)
        new_result = {
          :ems_ref       => snapshot.id,
          :type          => "ManageIQ::Providers::Google::CloudManager::CloudVolumeSnapshot",
          :name          => snapshot.name,
          :status        => snapshot.status,
          :creation_time => snapshot.creation_timestamp,
          :description   => snapshot.description,
          :size          => snapshot.disk_size_gb.to_i.gigabytes,
          :volume        => @data_index.fetch_path(:cloud_volumes, snapshot.source_disk)
        }

        return snapshot.self_link, new_result
      end

      def parse_image(image)
        uid    = image.id
        name   = image.name
        name ||= uid
        type   = ManageIQ::Providers::Google::CloudManager::Template.name

        new_result = {
          :type               => type,
          :uid_ems            => uid,
          :ems_ref            => uid,
          :name               => name,
          :vendor             => "google",
          :raw_power_state    => "never",
          :operating_system   => process_os(image),
          :template           => true,
          :publicly_available => true,
        }

        return uid, new_result
      end

      def process_os(image)
        {
          :product_name => OperatingSystem.normalize_os_name(image.name)
        }
      end

      def parse_ssh_key(ssh_key)
        uid = "#{ssh_key[:name]}:#{ssh_key[:fingerprint]}"

        type = ManageIQ::Providers::Google::CloudManager::AuthKeyPair.name
        new_result = {
          :type        => type,
          :name        => ssh_key[:name],
          :fingerprint => ssh_key[:fingerprint],
        }

        return uid, new_result
      end

      def parse_instance(instance)
        uid    = instance.id
        name   = instance.name
        name ||= uid

        flavor_uid       = parse_uid_from_url(instance.machine_type)
        flavor           = @data_index.fetch_path(:flavors, flavor_uid)

        zone_uid         = parse_uid_from_url(instance.zone)
        zone             = @data_index.fetch_path(:availability_zones, zone_uid)

        parent_image_uid = parse_instance_parent_image(instance)
        parent_image     = @data_index.fetch_path(:vms, parent_image_uid)

        cloud_network    = parse_instance_cloud_network(instance)
        security_groups  = parse_instance_security_groups(instance)

        operating_system = parent_image[:operating_system] unless parent_image.nil?

        type = ManageIQ::Providers::Google::CloudManager::Vm.name
        new_result = {
          :type              => type,
          :uid_ems           => uid,
          :ems_ref           => uid,
          :name              => name,
          :description       => instance.description,
          :vendor            => "google",
          :raw_power_state   => instance.state,
          :flavor            => flavor,
          :availability_zone => zone,
          :parent_vm         => parent_image,
          :operating_system  => operating_system,
          :key_pairs         => [],
          :cloud_network     => cloud_network,
          :security_groups   => security_groups,
          :hardware          => {
            :cpu_sockets          => flavor[:cpus],
            :cpu_total_cores      => flavor[:cpu_cores],
            :cpu_cores_per_socket => 1,
            :memory_mb            => flavor[:memory] / 1.megabyte,
            :disks                => [], # populated below
            :networks             => [], # populated below
          }
        }

        populate_hardware_hash_with_disks(new_result[:hardware][:disks], instance)
        populate_key_pairs_with_ssh_keys(new_result[:key_pairs], instance)
        populate_hardware_hash_with_networks(new_result[:hardware][:networks], instance)

        return uid, new_result
      end

      def populate_hardware_hash_with_disks(hardware_disks_array, instance)
        instance.disks.each do |attached_disk|
          # lookup the full disk information from the data_index by source link
          d = @data_index.fetch_path(:cloud_volumes, attached_disk["source"])

          next if d.nil?

          disk_size     = d[:size]
          disk_name     = attached_disk["deviceName"]
          disk_location = attached_disk["index"]

          disk = add_instance_disk(hardware_disks_array, disk_size, disk_name, disk_location)
          # Link the disk and the instance together
          disk[:backing]      = d
          disk[:backing_type] = 'CloudVolume'
        end
      end

      def populate_hardware_hash_with_networks(hardware_networks_array, instance)
        instance.network_interfaces.each do |nic|
          network_uid = parse_uid_from_url(nic["network"])

          hardware_networks_array << {
            :description => "#{network_uid} private",
            :ipaddress   => nic["networkIP"]
          }

          nic["accessConfigs"].to_a.each do |nic_access|
            hardware_networks_array << {
              :description => "#{network_uid} #{nic_access["name"]}",
              :ipaddress   => nic_access["natIP"]
            }
          end
        end
      end

      def add_instance_disk(disks, size, name, location)
        super(disks, size, location, name, "google")
      end

      def parse_instance_networks(instance)
        instance.network_interfaces.to_a.collect do |nic|
          parse_uid_from_url(nic["network"])
        end
      end

      def parse_instance_cloud_network(instance)
        network_name = parse_instance_networks(instance).first

        @data[:cloud_networks].to_a.detect do |net|
          net[:name] == network_name
        end
      end

      def parse_instance_security_groups(instance)
        parse_instance_networks(instance).collect do |network_name|
          @data_index.fetch_path(:security_groups, network_name)
        end
      end

      def parse_instance_parent_image(instance)
        parent_image_uid = nil

        instance.disks.each do |disk|
          parent_image_uid = @disk_to_source_image_id[disk["source"]]
          next if parent_image_uid.nil?
          break
        end

        parent_image_uid
      end

      def populate_key_pairs_with_ssh_keys(result_key_pairs, instance)
        # Add project common ssh-keys with keys specific to this instance
        instance_ssh_keys = parse_compute_metadata_ssh_keys(instance.metadata) | @project_key_pairs

        instance_ssh_keys.each do |ssh_key|
          key_uid = "#{ssh_key[:name]}:#{ssh_key[:fingerprint]}"
          kp = @data_index.fetch_path(:key_pairs, key_uid)
          result_key_pairs << kp unless kp.nil?
        end
      end

      def parse_compute_metadata(metadata, key)
        metadata_item = metadata["items"].to_a.detect { |x| x["key"] == key }
        metadata_item.to_h["value"]
      end

      def parse_compute_metadata_ssh_keys(metadata)
        require 'sshkey'

        ssh_keys = []

        # Find the sshKeys property in the instance metadata
        metadata_ssh_keys = parse_compute_metadata(metadata, "sshKeys")

        metadata_ssh_keys.to_s.split("\n").each do |ssh_key|
          # Google returns the key in the form username:public_key
          name, public_key = ssh_key.split(":", 2)
          begin
            fingerprint = SSHKey.sha1_fingerprint(public_key)

            ssh_keys << {
              :name        => name,
              :public_key  => public_key,
              :fingerprint => fingerprint
            }
          rescue => err
            _log.warn("Failed to parse public key #{name}: #{err}")
          end
        end

        ssh_keys
      end

      def link_volumes_to_base_snapshots
        @data_index[:cloud_volumes].each do |_, volume|
          base_snapshot = volume[:base_snapshot]
          next if base_snapshot.nil?

          volume[:base_snapshot] = @data_index.fetch_path(:cloud_volume_snapshots, base_snapshot)
        end
      end

      def parse_uid_from_url(url)
        # A lot of attributes in gce are full URLs with the
        # uid being the last component.  This helper method
        # returns the last component of the url
        uid = url.split('/')[-1]
        uid
      end
    end
  end
end

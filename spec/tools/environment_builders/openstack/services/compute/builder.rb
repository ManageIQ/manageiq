require_relative 'data'

module Openstack
  module Services
    module Compute
      class Builder
        attr_reader :service, :flavors, :servers

        def self.build_all(ems, project)
          new(ems, project).build_all
        end

        def initialize(ems, project)
          @service = ems.connect(:tenant_name => project.name)
          @data    = Data.new
          @project = project

          # Collected data
          @flavors  = []
          @keypairs = []
          @servers  = []
        end

        def build_all
          find_or_create_flavors
          find_or_create_keypairs

          self
        end

        #
        # Create servers
        # Servers are separated from build_all, since it requires sources from several services
        #
        def build_servers(volume, network, image, networking)
          find_or_create_servers(volume.volumes,
                                 volume.volume_snapshots,
                                 network.networks,
                                 network.security_groups,
                                 image.images,
                                 networking)
          image.build_snapshots_from_servers(servers)
          find_or_create_servers(volume.volumes,
                                 volume.volume_snapshots,
                                 network.networks,
                                 network.security_groups,
                                 image.images,
                                 networking,
                                 :servers_from_snapshot)
          associate_ips(servers, network)
        end

        #
        # Do actions with specific servers
        #
        def do_action(server, action)
          puts "Checking action #{action} on server #{server.name}."
          if server.state == "ACTIVE"
            puts "Doing action #{action} on server #{server.name}."
            server.send(action)
          end
        end

        private

        def find_or_create_servers(volumes, _volume_snapshots, networks, security_groups, images, networking, data_method = :servers)
          servers = []
          @data.send(data_method).each do |server|
            if (image_name = server.delete(:__image_name))
              image = images.detect { |x| x.name == image_name }
              server.merge!(:image_ref => image.id) if image
            end

            if (server_volumes = server.delete(:__block_devices))
              server[:block_device_mapping_v2] = []
              server_volumes.each do |server_volume|
                name = server_volume.delete(:__name)
                server_volume[:uuid] = case server_volume[:source_type]
                                       when "image"
                                         images.detect { |x| x.name == name }.id
                                       when "volume"
                                         volumes.detect { |x| x.name == name }.id
                                       end
                server[:block_device_mapping_v2] << server_volume
              end
            end

            if (network_names = server.delete(:__network_names))
              nics = []
              network_names.each do |network_name|
                network = networks.detect { |x| x.name == network_name }
                nics << {"net_id" => network.id} if network
              end
              server.merge!(:nics => nics) if nics
            end

            if (flavor_name = server.delete(:__flavor_name))
              flavor = flavors.detect { |x| x.name == flavor_name }
              server.merge!(:flavor_ref => flavor.id) if flavor
            end

            # Do not replaces security group names with ids for nova
            if networking != :nova && (security_group_names = server.delete(:security_groups))
              security_group_names = [security_group_names] unless security_group_names.kind_of?(Array)

              security_group_ids = security_group_names.map do |security_group_name|
                security_groups.detect { |x| x.name == security_group_name }.id
              end
              server.merge!(:security_groups => security_group_ids) if security_group_ids
            end

            servers << find_or_create(@service.servers, server)
          end
          wait_for_servers(servers)

          @servers += servers
        end

        def associate_ips(servers, network)
          servers.each do |server|
            associate_ip(server, network)
          end
        end

        def associate_ip(server, network)
          puts "Finding floating ip on server #{server.name}"
          if server.addresses.blank? || (!server.addresses.blank? &&
             server.addresses.values.flatten.detect { |x| x["OS-EXT-IPS:type"] == 'floating' }.blank?)
            # Get first free floating IP
            floating_ip = network.free_floating_ips.first
            unless floating_ip
              puts "!!!! No free floating IPs left!!!!"
              return
            end

            ip_address = network.floating_ip_address(floating_ip)
            puts "Associating {:ip => #{ip_address}} to #{server.name}"
            server.associate_address(ip_address)

            # Reload the floating Ip, so it's no longer free and server so it shows it
            floating_ip.reload
            server.reload
          end
        end

        def wait_for_servers(servers)
          servers.each { |server| wait_for_server(server) }
        end

        def wait_for_server(server)
          print "Waiting for server #{server.name} to get in a desired state..."
          starting_shutdown_server = false

          loop do
            case server.reload.state
            when "ACTIVE", "PAUSED", "SUSPENDED", "SHELVED", "SHELVED_OFFLOADED"
              break
            when "ERROR"
              puts "Error creating server"
              exit 1
            when "SHUTOFF"
              # When our VCR labs goes down, it shuts off all the VMs, lets start them here
              unless starting_shutdown_server
                starting_shutdown_server = true
                puts "Server was shutoff, starting it again."
                server.start
              end
              print "."
              sleep 1
            else
              print "."
              sleep 1
            end
          end
          puts "Finished"
        end

        def find_or_create_flavors
          @data.flavors.each do |flavor_data|
            flavor = find_or_create(@service.flavors, flavor_data)
            unless flavor_data[:is_public]
              begin
                @service.add_flavor_access(flavor.id, @project.id)
              rescue Excon::Error::Conflict
                puts "Access already exists for flavor #{flavor.name} and project #{@project.name}."
              end
            end
            @flavors << flavor
          end
        end

        def find_or_create_keypairs
          @data.key_pairs.each do |key_pair|
            @keypairs << key_pair = find_or_create(@service.key_pairs, key_pair)

            if key_pair.private_key
              File.write(key_pair.name, key_pair.private_key)
              puts "Your new key_pair private key has been written to '#{key_pair.name}'"
            end
          end
        end
      end
    end
  end
end

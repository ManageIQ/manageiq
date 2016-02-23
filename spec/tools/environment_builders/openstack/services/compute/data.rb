require_relative '../base_data'

module Openstack
  module Services
    module Compute
      class Data < ::Openstack::Services::BaseData
        def flavor_translate_table
          {
            :ram       => :memory,
            :vcpus     => :cpus,
            :disk      => :root_disk_size,
            :ephemeral => :ephemeral_disk_size,
            :swap      => :swap_disk_size,
          }
        end

        def flavors
          [{:name      => "m1.ems_refresh_spec",
            :is_public => true,
            :vcpus     => 1,
            :ram       => 512, # MB
            :disk      => 1, # GB
            :ephemeral => 1, # GB
            :swap      => 512, # MB
          }, {
            :name      => "m1.tiny",
            :is_public => true,
            :vcpus     => 1,
            :ram       => 512, # MB
            :disk      => 1, # GB
            :ephemeral => 0, # GB
            :swap      => 0, # MB
          }, {
            :name      => "m1.small",
            :is_public => true,
            :vcpus     => 1,
            :ram       => 2_048, # MB
            :disk      => 20, # GB
            :ephemeral => 0, # GB
            :swap      => 0, # MB
          }, {
            :name      => "m1.medium",
            :is_public => true,
            :vcpus     => 2,
            :ram       => 4_096, # MB
            :disk      => 40, # GB
            :ephemeral => 0, # GB
            :swap      => 0, # MB
          }, {
            :name      => "m1.large",
            :is_public => true,
            :vcpus     => 4,
            :ram       => 8_192, # MB
            :disk      => 80, # GB
            :ephemeral => 0, # GB
            :swap      => 0, # MB
          }, {
            :name      => "m1.xlarge",
            :is_public => true,
            :vcpus     => 8,
            :ram       => 16_384, # MB
            :disk      => 160, # GB
            :ephemeral => 0, # GB
            :swap      => 0, # MB
          }]
        end

        def key_pairs
          [{:name => "EmsRefreshSpec-KeyPair"}]
        end

        def images
          [{:name => "EmsRefreshSpec-Image"}]
        end

        def servers
          [{
            :name                => "EmsRefreshSpec-PoweredOn",
            :__flavor_name       => "m1.ems_refresh_spec",
            :__image_name        => "EmsRefreshSpec-Image",
            :__block_device_name => "EmsRefreshSpec-Volume",
            :__network_names     => ["EmsRefreshSpec-NetworkPrivate"],
            :key_name            => "EmsRefreshSpec-KeyPair",
            :security_groups     => ["EmsRefreshSpec-SecurityGroup", "EmsRefreshSpec-SecurityGroup2"]
          }, {
            :name            => "EmsRefreshSpec-Paused",
            :__flavor_name   => "m1.ems_refresh_spec",
            :__image_name    => "EmsRefreshSpec-Image",
            :__network_names => ["EmsRefreshSpec-NetworkPrivate"],
            :key_name        => "EmsRefreshSpec-KeyPair",
            :security_groups => "EmsRefreshSpec-SecurityGroup"
          }, {
            :name            => "EmsRefreshSpec-Suspended",
            :__flavor_name   => "m1.ems_refresh_spec",
            :__image_name    => "EmsRefreshSpec-Image",
            :__network_names => ["EmsRefreshSpec-NetworkPrivate"],
            :key_name        => "EmsRefreshSpec-KeyPair",
            :security_groups => "EmsRefreshSpec-SecurityGroup"
          }, {
            :name            => "EmsRefreshSpec-Shelved",
            :__flavor_name   => "m1.ems_refresh_spec",
            :__image_name    => "EmsRefreshSpec-Image",
            :__network_names => ["EmsRefreshSpec-NetworkPrivate"],
            :key_name        => "EmsRefreshSpec-KeyPair",
            :security_groups => "EmsRefreshSpec-SecurityGroup"}]
        end

        def servers_from_snapshot
          [{
            :name            => "EmsRefreshSpec-PoweredOn-FromSnapshot",
            :__flavor_name   => "m1.ems_refresh_spec",
            :__image_name    => "EmsRefreshSpec-PoweredOn-SnapShot",
            :__network_names => ["EmsRefreshSpec-NetworkPrivate"],
            :key_name        => "EmsRefreshSpec-KeyPair",
            :security_groups => ["EmsRefreshSpec-SecurityGroup", "EmsRefreshSpec-SecurityGroup2"]}]
        end
      end
    end
  end
end

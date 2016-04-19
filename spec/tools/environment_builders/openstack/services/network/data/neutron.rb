require_relative '../../base_data'

module Openstack
  module Services
    module Network
      class Data
        class Neutron < ::Openstack::Services::BaseData
          PUBLIC_NETWORK_NAME             = "EmsRefreshSpec-NetworkPublic"
          PUBLIC_NETWORK_NAME_10          = "EmsRefreshSpec-NetworkPublic_10"
          PUBLIC_NETWORK_NAME_20          = "EmsRefreshSpec-NetworkPublic_20"
          PUBLIC_NETWORK_NAME_30          = "EmsRefreshSpec-NetworkPublic_30"
          PUBLIC_NETWORK_NAME_40          = "EmsRefreshSpec-NetworkPublic_40"
          PUBLIC_NETWORK_NAME_50          = "EmsRefreshSpec-NetworkPublic_50"
          PRIVATE_NETWORK_NAME            = "EmsRefreshSpec-NetworkPrivate"
          PRIVATE_NETWORK_NAME_2          = "EmsRefreshSpec-NetworkPrivate_2"
          PRIVATE_NETWORK_NAME_3          = "EmsRefreshSpec-NetworkPrivate_3"
          PRIVATE_NETWORK_NAME_20         = "EmsRefreshSpec-NetworkPrivate_20"
          PRIVATE_NETWORK_NAME_30         = "EmsRefreshSpec-NetworkPrivate_30"
          ISOLATED_PRIVATE_NETWORK_NAME_1 = "EmsRefreshSpec-IsolatedNetworkPrivate_1"
          ISOLATED_PRIVATE_NETWORK_NAME_2 = "EmsRefreshSpec-IsolatedNetworkPrivate_2"
          ROUTER_NAME                     = "EmsRefreshSpec-Router"

          def network_translate_table
            {
              :router_external            => :external_facing,
              "provider:network_type"     => :provider_network_type,
              "provider:physical_network" => :provider_physical_network
            }
          end

          def networks
            [{
              :name                       => PUBLIC_NETWORK_NAME,
              :router_external            => true,
              "provider:network_type"     => "flat",
              "provider:physical_network" => "public_net_0",
            }, {
              :name                       => PUBLIC_NETWORK_NAME_10,
              :router_external            => true,
              "provider:network_type"     => "flat",
              "provider:physical_network" => "public_net_1",
            }, {
              :name                       => PUBLIC_NETWORK_NAME_20,
              :router_external            => true,
              "provider:network_type"     => "flat",
              "provider:physical_network" => "public_net_2",
            }, {
              :name                       => PUBLIC_NETWORK_NAME_30,
              :router_external            => true,
              "provider:network_type"     => "flat",
              "provider:physical_network" => "public_net_3",
            }, {
              :name                       => PUBLIC_NETWORK_NAME_40,
              :router_external            => true,
              "provider:network_type"     => "flat",
              "provider:physical_network" => "public_net_4",
            }, {
              :name                       => PUBLIC_NETWORK_NAME_50,
              :router_external            => true,
              "provider:network_type"     => "flat",
              "provider:physical_network" => "public_net_5",
            }, {
              :name                   => PRIVATE_NETWORK_NAME,
              :router_external        => false,
              "provider:network_type" => "vxlan",
            }, {
              :name                   => PRIVATE_NETWORK_NAME_2,
              :router_external        => false,
              "provider:network_type" => "vxlan",
            }, {
              :name                   => PRIVATE_NETWORK_NAME_3,
              :router_external        => false,
              "provider:network_type" => "vxlan",
            }, {
              :name                   => PRIVATE_NETWORK_NAME_20,
              :router_external        => false,
              "provider:network_type" => "vxlan",
            }, {
              :name                   => PRIVATE_NETWORK_NAME_30,
              :router_external        => false,
              "provider:network_type" => "vxlan",
            }, {
              :name                   => ISOLATED_PRIVATE_NETWORK_NAME_1,
              :router_external        => false,
              "provider:network_type" => "vxlan",
            }, {
              :name                   => ISOLATED_PRIVATE_NETWORK_NAME_2,
              :router_external        => false,
              "provider:network_type" => "vxlan",
            }]
          end

          def subnet_translate_table
            {
              :gateway_ip  => :gateway,
              :ip_version  => :network_protocol,
              :enable_dhcp => :dhcp_enabled
            }
          end

          def subnets(network_name = nil)
            subnets = {
              PUBLIC_NETWORK_NAME => [{
                :name             => "EmsRefreshSpec-SubnetPublic",
                :cidr             => "172.16.17.0/24",
                :gateway_ip       => "172.16.17.1",
                :ip_version       => "4",
                :enable_dhcp      => false,
                :allocation_pools => [{
                  "start" => "172.16.17.2",
                  "end"   => "172.16.17.9"
                }, {
                  "start" => "172.16.17.11",
                  "end"   => "172.16.17.19"
                }]
              }],
              PUBLIC_NETWORK_NAME_10 => [{
                :name        => "EmsRefreshSpec-SubnetPublic_10",
                :cidr        => "172.16.18.0/24",
                :gateway_ip  => "172.16.18.1",
                :ip_version  => "4",
                :enable_dhcp => false}],
              PUBLIC_NETWORK_NAME_20 => [{
                :name             => "EmsRefreshSpec-SubnetPublic_20",
                :cidr             => "172.16.19.0/24",
                :gateway_ip       => "172.16.19.1",
                :ip_version       => "4",
                :enable_dhcp      => false,
                :allocation_pools => [{
                  "start" => "172.16.19.21",
                  "end"   => "172.16.19.23"}]}],
              PUBLIC_NETWORK_NAME_30 => [{
                :name        => "EmsRefreshSpec-SubnetPublic_30",
                :cidr        => "172.16.20.0/24",
                :gateway_ip  => "172.16.20.1",
                :ip_version  => "4",
                :enable_dhcp => false
              }],
              PUBLIC_NETWORK_NAME_40 => [{
                :name        => "EmsRefreshSpec-SubnetPublic_40",
                :cidr        => "172.16.21.0/24",
                :gateway_ip  => "172.16.21.1",
                :ip_version  => "4",
                :enable_dhcp => false
              }],
              PUBLIC_NETWORK_NAME_50 => [{
                :name        => "EmsRefreshSpec-SubnetPublic_50",
                :cidr        => "172.16.50.0/24",
                :gateway_ip  => "172.16.50.1",
                :ip_version  => "4",
                :enable_dhcp => false
              }, {
                :name        => "EmsRefreshSpec-SubnetPublic_51",
                :cidr        => "172.16.51.0/24",
                :gateway_ip  => "172.16.51.1",
                :ip_version  => "4",
                :enable_dhcp => false
              }],
              PRIVATE_NETWORK_NAME => [{
                :name             => "EmsRefreshSpec-SubnetPrivate",
                :cidr             => "192.168.0.0/24",
                :gateway_ip       => "192.168.0.1",
                :dns_nameservers  => ["8.8.8.8"],
                :ip_version       => "4",
                :allocation_pools => [{
                  "start" => "192.168.0.3",
                  "end"   => "192.168.0.5"
                }, {
                  "start" => "192.168.0.8",
                  "end"   => "192.168.0.8"
                }]
              }, {
                :name            => "EmsRefreshSpec-SubnetPrivate_12",
                :cidr            => "192.168.1.0/24",
                :gateway_ip      => "192.168.1.1",
                :dns_nameservers => ["8.8.8.8"],
                :ip_version      => "4"
                # TODO(lsmola) test also IPV6, fill in correct cidr and gateway
                # }, {
                #   :name       => "EmsRefreshSpec-SubnetPrivate3",
                #   :cidr       => "192.168.2.0/24",
                #   :gateway_ip => "192.168.3.1",
                #   :ip_version => "6"
              }],
              PRIVATE_NETWORK_NAME_2 => [{
                :name       => "EmsRefreshSpec-SubnetPrivate_2",
                :cidr       => "192.168.2.0/24",
                :gateway_ip => "192.168.2.1",
                :ip_version => "4"
              }],
              PRIVATE_NETWORK_NAME_3 => [{
                :name             => "EmsRefreshSpec-SubnetPrivate_3",
                :cidr             => "192.168.3.0/24",
                :gateway_ip       => "192.168.3.1",
                :ip_version       => "4",
                :allocation_pools => [
                  {
                    "start" => "192.168.3.2",
                    "end"   => "192.168.3.6"
                  }, {
                    "start" => "192.168.3.8",
                    "end"   => "192.168.3.10"
                  }
                ]
              }],
              PRIVATE_NETWORK_NAME_20 => [{
                :name       => "EmsRefreshSpec-SubnetPrivate_20",
                :cidr       => "192.168.20.0/24",
                :gateway_ip => "192.168.20.1",
                :ip_version => "4",
              }],
              PRIVATE_NETWORK_NAME_30 => [{
                :name       => "EmsRefreshSpec-SubnetPrivate_30",
                :cidr       => "192.168.30.0/24",
                :gateway_ip => "192.168.30.1",
                :ip_version => "4",
              }, {
                :name       => "EmsRefreshSpec-SubnetPrivate_31",
                :cidr       => "192.168.31.0/24",
                :gateway_ip => "192.168.31.1",
                :ip_version => "4",
              }],
              ISOLATED_PRIVATE_NETWORK_NAME_1 => [{
                :name       => "EmsRefreshSpec-IsolatedSubnetPrivate_1",
                :cidr       => "192.168.40.0/24",
                :gateway_ip => "192.168.40.1",
                :ip_version => "4"
              }],
              ISOLATED_PRIVATE_NETWORK_NAME_2 => [{
                :name             => "EmsRefreshSpec-IsolatedSubnetPrivate_2",
                :cidr             => "192.168.50.0/24",
                :gateway_ip       => "192.168.50.1",
                :ip_version       => "4",
                :allocation_pools => [{
                  "start" => "192.168.50.2",
                  "end"   => "192.168.50.2"
                }, {
                  "start" => "192.168.50.4",
                  "end"   => "192.168.50.4"
                }],
              }, {
                :name       => "EmsRefreshSpec-IsolatedSubnetPrivate_21",
                :cidr       => "192.168.51.0/24",
                :gateway_ip => "192.168.51.1",
                :ip_version => "4"
              }]}

            indexed_collection_return(subnets, network_name)
          end

          def routers(network_name = nil)
            routers = {
              PUBLIC_NETWORK_NAME    => [
                {
                  :name      => ROUTER_NAME,
                  :__subnets => subnets(PRIVATE_NETWORK_NAME)
                }, {
                  :name      => "EmsRefreshSpec-Router_2_3",
                  :__subnets => subnets(PRIVATE_NETWORK_NAME_2) + subnets(PRIVATE_NETWORK_NAME_3),
                }],
              PUBLIC_NETWORK_NAME_20 => [
                {
                  :name      => "EmsRefreshSpec-Router_20",
                  :__subnets => subnets(PRIVATE_NETWORK_NAME_20)
                }],
              # public network 30 and 40 will be connected to the same private network, to different subnets
              PUBLIC_NETWORK_NAME_30 => [
                {
                  :name      => "EmsRefreshSpec-Router_30",
                  :__subnets => [subnets(PRIVATE_NETWORK_NAME_30)[0]]
                }],
              PUBLIC_NETWORK_NAME_40 => [
                {
                  :name      => "EmsRefreshSpec-Router_40",
                  :__subnets => [subnets(PRIVATE_NETWORK_NAME_30)[1]]
                }],
              'non_existent_network' => [
                {
                  :name => "DisconnectedRouter"
                }]
            }

            indexed_collection_return(routers, network_name)
          end

          def floating_ips(network_name = nil)
            floating_ips = {
              PUBLIC_NETWORK_NAME => 10}

            indexed_collection_return(floating_ips, network_name)
          end

          def security_group_name_1
            "EmsRefreshSpec-SecurityGroup"
          end

          def security_groups
            [{:name        => security_group_name_1,
              :description => "EmsRefreshSpec-SecurityGroup description"},
             {:name        => "EmsRefreshSpec-SecurityGroup2",
              :description => "EmsRefreshSpec-SecurityGroup2 description"}]
          end

          def security_groups_rule_translate_table
            {
              :protocol         => :host_protocol,
              :ethertype        => :network_protocol,
              :port_range_min   => :port,
              :port_range_max   => :end_port,
              :remote_ip_prefix => :source_ip_range
            }
          end

          def security_group_rules(security_group_name = nil)
            security_groups = {
              security_group_name_1 => [{
                :direction        => "ingress",
                :protocol         => "icmp",
                :ethertype        => "IPv4",
                :remote_ip_prefix => "0.0.0.0/0"
              }, {
                :direction        => "ingress",
                :protocol         => "icmp",
                :ethertype        => "IPv4",
                :remote_ip_prefix => "1.2.3.4/30"
              }, {
                :direction         => "ingress",
                :protocol          => "icmp",
                :ethertype         => "IPv4",
                :__remote_group_id => "security_group"
              }, {
                :direction        => "ingress",
                :protocol         => "tcp",
                :ethertype        => "IPv4",
                :port_range_min   => 1,
                :port_range_max   => 65_535,
                :remote_ip_prefix => "0.0.0.0/0"
              }, {
                :direction        => "ingress",
                :protocol         => "tcp",
                :ethertype        => "IPv4",
                :port_range_min   => 1,
                :port_range_max   => 2,
                :remote_ip_prefix => "1.2.3.4/30"
              }, {
                :direction         => "ingress",
                :protocol          => "tcp",
                :ethertype         => "IPv4",
                :port_range_min    => 3,
                :port_range_max    => 4,
                :__remote_group_id => "security_group"
              }, {
                :direction        => "ingress",
                :protocol         => "tcp",
                :ethertype        => "IPv4",
                :port_range_min   => 80,
                :port_range_max   => 80,
                :remote_ip_prefix => "0.0.0.0/0"
              }, {
                :direction        => "ingress",
                :protocol         => "tcp",
                :ethertype        => "IPv4",
                :port_range_min   => 80,
                :port_range_max   => 80,
                :remote_ip_prefix => "1.2.3.4/30"
              }, {
                :direction         => "ingress",
                :protocol          => "tcp",
                :ethertype         => "IPv4",
                :port_range_min    => 80,
                :port_range_max    => 80,
                :__remote_group_id => "security_group"
              }, {
                :direction        => "ingress",
                :protocol         => "udp",
                :ethertype        => "IPv4",
                :port_range_min   => 1,
                :port_range_max   => 65_535,
                :remote_ip_prefix => "0.0.0.0/0"
              }, {
                :direction        => "ingress",
                :protocol         => "udp",
                :ethertype        => "IPv4",
                :port_range_min   => 1,
                :port_range_max   => 2,
                :remote_ip_prefix => "1.2.3.4/30"
              }, {
                :direction         => "ingress",
                :protocol          => "udp",
                :ethertype         => "IPv4",
                :port_range_min    => 3,
                :port_range_max    => 4,
                :__remote_group_id => "security_group"
              }, {
                :direction        => "ingress",
                :protocol         => "tcp",
                :ethertype        => "IPv6",
                :port_range_min   => 443,
                :port_range_max   => 443,
                :remote_ip_prefix => "::/0"
              }, {
                :direction        => "ingress",
                :protocol         => "tcp",
                :ethertype        => "IPv6",
                :port_range_min   => 443,
                :port_range_max   => 443,
                :remote_ip_prefix => "1:2:3:4:5:6:7:abc8/128"
              }, {
                :direction         => "ingress",
                :protocol          => "tcp",
                :ethertype         => "IPv6",
                :port_range_min    => 443,
                :port_range_max    => 443,
                :__remote_group_id => "security_group"
              }, {
                :direction        => "egress",
                :protocol         => "tcp",
                :ethertype        => "IPv6",
                :port_range_min   => 443,
                :port_range_max   => 443,
                :remote_ip_prefix => "::/0"
              }, {
                :direction        => "egress",
                :protocol         => "tcp",
                :ethertype        => "IPv4",
                :port_range_min   => 443,
                :port_range_max   => 443,
                :remote_ip_prefix => "1.2.3.4/30"
              }, {
                :direction         => "egress",
                :protocol          => "tcp",
                :ethertype         => "IPv6",
                :port_range_min    => 443,
                :port_range_max    => 443,
                :__remote_group_id => "security_group"}]}

            indexed_collection_return(security_groups, security_group_name)
          end
        end
      end
    end
  end
end

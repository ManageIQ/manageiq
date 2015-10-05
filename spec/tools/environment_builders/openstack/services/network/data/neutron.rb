require_relative '../../base_data'

module Openstack
  module Services
    module Network
      class Data
        class Neutron < ::Openstack::Services::BaseData
          def public_network_name
            "EmsRefreshSpec-NetworkPublic"
          end

          def private_network_name
            "EmsRefreshSpec-NetworkPrivate"
          end

          def network_translate_table
            {:router_external => :external_facing}
          end

          def networks
            [{
              :name            => public_network_name,
              :router_external => true
            }, {
              :name            => private_network_name,
              :router_external => false
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
              public_network_name  => [{
                :name             => "EmsRefreshSpec-SubnetPublic",
                :cidr             => "10.8.96.0/22",
                :gateway_ip       => "10.8.99.254",
                :ip_version       => "4",
                :enable_dhcp      => false,
                :allocation_pools => [{"start" => "10.8.97.1",
                                       "end"   => "10.8.97.9"}]}],
              private_network_name => [{
                :name       => "EmsRefreshSpec-SubnetPrivate",
                :cidr       => "192.168.0.0/24",
                :gateway_ip => "192.168.0.1",
                :ip_version => "4"}]}

            indexed_collection_return(subnets, network_name)
          end

          def routers(network_name = nil)
            routers = {
              public_network_name => [{
                :name      => "EmsRefreshSpec-Router",
                :__subnets => subnets(private_network_name)}]}

            indexed_collection_return(routers, network_name)
          end

          def floating_ips(network_name = nil)
            floating_ips = {
              public_network_name => 4}

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

require_relative '../../base_data'

module Openstack
  module Services
    module Network
      class Data
        class Nova < ::Openstack::Services::BaseData
          def network_translate_table
            {}
          end

          def networks
            []
          end

          def subnet_translate_table
            {}
          end

          def subnets(_network_name = nil)
            []
          end

          def routers(_network_name = nil)
            []
          end

          def floating_ips(nova_pool_name = nil)
            floating_ips = {
              'nova' => 4}

            indexed_collection_return(floating_ips, nova_pool_name)
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
              :ip_protocol => :host_protocol,
              :from_port   => :port,
              :to_port     => :end_port,
              :ip_range    => :source_ip_range
            }
          end

          def security_group_rules(security_group_name = nil)
            security_groups = {
              security_group_name_1 => [{
                :from_port   => 1,
                :to_port     => 2,
                :ip_protocol => 'tcp',
                :ip_range    => {
                  :cidr => '0.0.0.0/0'}
              }, {
                :from_port   => 1,
                :to_port     => 65_535,
                :ip_protocol => 'tcp',
                :ip_range    => {
                  :cidr => '0.0.0.0/0'}
              }, {
                :from_port   => 3,
                :to_port     => 4,
                :ip_protocol => 'tcp',
                :ip_range    => {},
                :group       => {
                  :name => 'EmsRefreshSpec-SecurityGroup'}
              }, {
                :from_port   => 80,
                :to_port     => 80,
                :ip_protocol => 'tcp',
                :ip_range    => {
                  :cidr => '0.0.0.0/0'}
              }, {
                :from_port   => 80,
                :to_port     => 80,
                :ip_protocol => 'tcp',
                :ip_range    => {},
                :group       => {
                  :name => 'EmsRefreshSpec-SecurityGroup'}
              }, {
                :from_port   => 1,
                :to_port     => 2,
                :ip_protocol => 'udp',
                :ip_range    => {
                  :cidr => '0.0.0.0/0'}
              }, {
                :from_port   => 1,
                :to_port     => 65_535,
                :ip_protocol => 'udp',
                :ip_range    => {
                  :cidr => '0.0.0.0/0'}
              }, {
                :from_port   => 3,
                :to_port     => 4,
                :ip_protocol => 'udp',
                :ip_range    => {},
                :group       => {
                  :name => 'EmsRefreshSpec-SecurityGroup'}
              }, {
                :from_port   => 0,
                :to_port     => 0,
                :ip_protocol => 'icmp',
                :ip_range    => {
                  :cidr => '0.0.0.0/0'}
              }, {
                :from_port   => 3,
                :to_port     => 4,
                :ip_protocol => 'icmp',
                :ip_range    => {},
                :group       => {
                  :name => 'EmsRefreshSpec-SecurityGroup'}
              }]}

            indexed_collection_return(security_groups, security_group_name)
          end
        end
      end
    end
  end
end

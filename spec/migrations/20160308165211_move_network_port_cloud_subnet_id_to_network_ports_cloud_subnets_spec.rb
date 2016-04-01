require "spec_helper"
require_migration

describe MoveNetworkPortCloudSubnetIdToNetworkPortsCloudSubnets do
  let(:cloud_subnet_stub) { migration_stub(:CloudSubnet) }
  let(:network_port_stub) { migration_stub(:NetworkPort) }
  let(:cloud_subnet_network_port_stub) { migration_stub(:CloudSubnetNetworkPort) }

  let(:cloud_subnet_entries) do
    [
      {
        :type         => "ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet",
        :name         => "cs1"
      },
      {
        :type         => "ManageIQ::Providers::Azure::CloudManager::CloudSubnet",
        :name         => "cs2"
      },
      {
        :type         => "ManageIQ::Providers::Amazon::CloudManager::CloudSubnet",
        :name         => "cs3"
      },
      {
        :type         => "ManageIQ::Providers::AnotherManager::CloudManager::CloudSubnet",
        :name         => "cs4"
      }
    ]
  end

  let(:network_port_entries) do
    [
      {
        :type         => "ManageIQ::Providers::Openstack::NetworkManager::NetworkPort",
        :cloud_subnet => cloud_subnet_entries[0],
        :name         => "np1"
      },
      {
        :type         => "ManageIQ::Providers::Azure::CloudManager::NetworkPort",
        :cloud_subnet => cloud_subnet_entries[1],
        :name         => "np2"
      },
      {
        :type         => "ManageIQ::Providers::Amazon::CloudManager::NetworkPort",
        :cloud_subnet => cloud_subnet_entries[2],
        :name         => "np3"
      },
      {
        :type         => "ManageIQ::Providers::AnotherManager::CloudManager::NetworkPort",
        :cloud_subnet => cloud_subnet_entries[3],
        :name         => "np4"
      }
    ]
  end

  let(:cloud_subnet_network_port_entries) do
    [
      {
        :network_port => network_port_entries[0],
        :cloud_subnet => cloud_subnet_entries[0],
        :address      => "addr1"
      },
      {
        :network_port => network_port_entries[1],
        :cloud_subnet => cloud_subnet_entries[1],
        :address      => "addr1"
      },
      {
        :network_port => network_port_entries[2],
        :cloud_subnet => cloud_subnet_entries[2],
        :address      => "addr1"
      },
      {
        :network_port => network_port_entries[3],
        :cloud_subnet => cloud_subnet_entries[3],
        :address      => "addr1"
      }
    ]
  end

  migration_context :up do
    it "migrates a series of representative row" do
      cloud_subnet_entries.each do |x|
        x[:object] = cloud_subnet_stub.create!(
          :type => x[:type],
          :name => x[:name])
      end

      network_port_entries.each do |x|
        x[:object] = network_port_stub.create!(
          :type            => x[:type],
          :cloud_subnet_id => x[:cloud_subnet][:object].id,
          :name            => x[:name])
      end

      expect(cloud_subnet_network_port_stub.count).to eq 0

      migrate

      network_port_entries.each do |network_port|
        expect(cloud_subnet_network_port_stub.find_by(:network_port_id => network_port[:object].id).cloud_subnet_id).to eq network_port[:object][:cloud_subnet_id]
      end

      expect(cloud_subnet_network_port_stub.count).to eq 4
    end
  end

  migration_context :down do
    it "migrates a series of representative row" do
      cloud_subnet_entries.each do |x|
        x[:object] = cloud_subnet_stub.create!(
          :type => x[:type],
          :name => x[:name])
      end

      network_port_entries.each do |x|
        x[:object] = network_port_stub.create!(
          :type            => x[:type],
          :name            => x[:name])
      end

      cloud_subnet_network_port_entries.each do |x|
        x[:object] = cloud_subnet_network_port_stub.create!(
          :address         => x[:address],
          :cloud_subnet_id => x[:cloud_subnet][:object].id,
          :network_port_id => x[:network_port][:object].id)
      end

      expect(cloud_subnet_network_port_stub.count).to eq 4

      migrate

      cloud_subnet_network_port_entries.each do |cloud_subnet_network_port|
        expect(network_port_stub.find_by(:id => cloud_subnet_network_port[:object].network_port_id).cloud_subnet_id).to eq cloud_subnet_network_port[:object][:cloud_subnet_id]
      end

      expect(cloud_subnet_network_port_stub.count).to eq 0
    end
  end
end

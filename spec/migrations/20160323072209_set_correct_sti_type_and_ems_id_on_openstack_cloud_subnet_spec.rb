require_migration

describe SetCorrectStiTypeAndEmsIdOnOpenstackCloudSubnet do
  let(:ext_management_system_stub) { migration_stub(:ExtManagementSystem) }
  let(:cloud_network_stub) { migration_stub(:CloudNetwork) }
  let(:cloud_subnet_stub) { migration_stub(:CloudSubnet) }

  let(:ems_row_entries) do
    [
      {:type => "ManageIQ::Providers::Openstack::CloudManager"},
      {:type => "ManageIQ::Providers::Openstack::InfraManager"},
      {:type => "ManageIQ::Providers::Amazon::CloudManager"},
      {:type => "ManageIQ::Providers::AnotherManager::CloudManager"}
    ]
  end

  let(:ems_network_row_entries) do
    [
      {
        :type       => "ManageIQ::Providers::Openstack::NetworkManager",
        :parent_ems => ems_row_entries[0]
      },
      {
        :type       => "ManageIQ::Providers::Openstack::NetworkManager",
        :parent_ems => ems_row_entries[1]
      },
      {
        :type       => "ManageIQ::Providers::Amazon::NetworkManager",
        :parent_ems => ems_row_entries[2]
      },
      {
        :type       => "ManageIQ::Providers::AnotherManager::NetworkManager",
        :parent_ems => ems_row_entries[3]
      }
    ]
  end

  let(:network_row_entries) do
    [
      {
        :ems  => ems_network_row_entries[0],
        :name => "network_1",
        :type => 'ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private',
      },
      {
        :ems  => ems_network_row_entries[1],
        :name => "network_2",
        :type => 'ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private',
      },
      {
        :ems  => ems_network_row_entries[2],
        :name => "network_3",
        :type => 'ManageIQ::Providers::Amazon::CloudManager::CloudNetwork',
      },
      {
        :ems  => ems_network_row_entries[3],
        :name => "network_4",
        :type => nil,
      },
      {
        :ems  => ems_network_row_entries[3],
        :name => "network_5",
        :type => 'ManageIQ::Providers::AnyManager::CloudNetwork',
      },
    ]
  end

  let(:subnet_row_entries) do
    [
      {
        :cloud_network => network_row_entries[0],
        :name          => "subnet_1",
        :type_in       => 'ManageIQ::Providers::Openstack::CloudManager::CloudSubnet',
        :type_out      => 'ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet',
        :ems_out       => ems_network_row_entries[0]
      },
      {
        :cloud_network => network_row_entries[1],
        :name          => "subnet_2",
        :type_in       => 'ManageIQ::Providers::Openstack::InfraManager::CloudSubnet',
        :type_out      => 'ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet',
        :ems_out       => ems_network_row_entries[1]
      },
      {
        :cloud_network => network_row_entries[2],
        :name          => "subnet_3",
        :type_in       => 'ManageIQ::Providers::Amazon::CloudManager::CloudSubnet',
        :type_out      => 'ManageIQ::Providers::Amazon::CloudManager::CloudSubnet',
        :ems_out       => nil
      },
      {
        :cloud_network => network_row_entries[3],
        :name          => "subnet_4",
        :type_in       => nil,
        :type_out      => nil,
        :ems_out       => nil
      },
      {
        :cloud_network => network_row_entries[4],
        :name          => "subnet_5",
        :type_in       => 'ManageIQ::Providers::AnyManager::CloudSubnet',
        :type_out      => 'ManageIQ::Providers::AnyManager::CloudSubnet',
        :ems_out       => nil
      },
    ]
  end

  migration_context :up do
    it "migrates a series of representative row" do
      ems_row_entries.each do |x|
        x[:ems] = ext_management_system_stub.create!(:type => x[:type])
      end

      ems_network_row_entries.each do |x|
        x[:ems] = ext_management_system_stub.create!(:type          => x[:type],
                                                     :parent_ems_id => x[:parent_ems][:ems].id)
      end

      network_row_entries.each do |x|
        x[:cloud_network] = cloud_network_stub.create!(:type   => x[:type],
                                                       :ems_id => x[:ems][:ems].id,
                                                       :name   => x[:name])
      end

      subnet_row_entries.each do |x|
        x[:cloud_subnet] = cloud_subnet_stub.create!(:type             => x[:type_in],
                                                     :cloud_network_id => x[:cloud_network][:cloud_network].id,
                                                     :name             => x[:name])
      end

      migrate

      subnet_row_entries.each do |x|
        expect(x[:cloud_subnet].reload).to have_attributes(
                                             :type   => x[:type_out],
                                             :name   => x[:name],
                                             :ems_id => x[:ems_out].try(:[], :ems).try(:[], :id)
                                           )
      end
    end
  end

  migration_context :down do
    it "migrates a series of representative row" do
      ems_row_entries.each do |x|
        x[:ems] = ext_management_system_stub.create!(:type => x[:type])
      end

      ems_network_row_entries.each do |x|
        x[:ems] = ext_management_system_stub.create!(:type          => x[:type],
                                                     :parent_ems_id => x[:parent_ems][:ems].id)
      end

      network_row_entries.each do |x|
        x[:cloud_network] = cloud_network_stub.create!(:type   => x[:type],
                                                       :ems_id => x[:ems][:ems].id,
                                                       :name   => x[:name])
      end

      subnet_row_entries.each do |x|
        x[:cloud_subnet] = cloud_subnet_stub.create!(:type             => x[:type_out],
                                                     :cloud_network_id => x[:cloud_network][:cloud_network].id,
                                                     :name             => x[:name],
                                                     :ems_id           => x[:ems_out].try(:[], :ems).try(:[], :id))
      end

      migrate

      subnet_row_entries.each do |x|
        expect(x[:cloud_subnet].reload).to have_attributes(
                                             :type   => x[:type_in],
                                             :name   => x[:name],
                                             :ems_id => x[:ems_out].try(:[], :ems).try(:[], :id)
                                           )
      end
    end
  end
end

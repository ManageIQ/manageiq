require_migration

describe SetCorrectStiTypeOnOpenstackCloudVolume do
  let(:ext_management_system_stub) { migration_stub(:ExtManagementSystem) }
  let(:cloud_volume_stub) { migration_stub(:CloudVolume) }

  let(:ems_row_entries) do
    [
      {:type => "ManageIQ::Providers::Openstack::CloudManager"},
      {:type => "ManageIQ::Providers::Amazon::CloudManager"},
      {:type => "ManageIQ::Providers::AnotherManager"}
    ]
  end

  let(:row_entries) do
    [
      {
        :ems      => ems_row_entries[0],
        :name     => "volume_1",
        :type_in  => nil,
        :type_out => 'ManageIQ::Providers::Openstack::CloudManager::CloudVolume'
      },
      {
        :ems      => ems_row_entries[1],
        :name     => "volume_2",
        :type_in  => 'ManageIQ::Providers::Openstack::CloudManager::CloudVolume',
        :type_out => 'ManageIQ::Providers::Openstack::CloudManager::CloudVolume'
      },
      {
        :ems      => ems_row_entries[1],
        :name     => "volume_3",
        :type_in  => 'ManageIQ::Providers::Amazon::CloudManager::CloudVolume',
        :type_out => 'ManageIQ::Providers::Amazon::CloudManager::CloudVolume'
      },
      {
        :ems      => ems_row_entries[1],
        :name     => "volume_4",
        :type_in  => nil,
        :type_out => nil
      },
      {
        :ems      => ems_row_entries[2],
        :name     => "volume_5",
        :type_in  => 'ManageIQ::Providers::AnyManager::CloudVolume',
        :type_out => 'ManageIQ::Providers::AnyManager::CloudVolume'
      },
    ]
  end

  migration_context :up do
    it "migrates a series of representative row" do
      ems_row_entries.each do |x|
        x[:ems] = ext_management_system_stub.create!(:type => x[:type])
      end

      row_entries.each do |x|
        x[:cloud_volume] = cloud_volume_stub.create!(:type   => x[:type_in],
                                                     :ems_id => x[:ems][:ems].id,
                                                     :name   => x[:name])
      end

      migrate

      row_entries.each do |x|
        expect(x[:cloud_volume].reload).to have_attributes(
                                             :type   => x[:type_out],
                                             :name   => x[:name],
                                             :ems_id => x[:ems][:ems].id
                                           )
      end
    end
  end

  migration_context :down do
    it "migrates a series of representative row" do
      ems_row_entries.each do |x|
        x[:ems] = ext_management_system_stub.create!(:type => x[:type])
      end

      row_entries.each do |x|
        x[:cloud_volume] = cloud_volume_stub.create!(:type   => x[:type_out],
                                                     :ems_id => x[:ems][:ems].id,
                                                     :name   => x[:name])
      end

      migrate

      row_entries.each do |x|
        expect(x[:cloud_volume].reload).to have_attributes(
                                             :type   => x[:type_in],
                                             :name   => x[:name],
                                             :ems_id => x[:ems][:ems][:id]
                                           )
      end
    end
  end
end

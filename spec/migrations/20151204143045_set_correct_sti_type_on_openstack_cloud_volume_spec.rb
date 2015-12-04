require "spec_helper"
require_migration

describe SetCorrectStiTypeOnOpenstackCloudVolume do
  let(:ext_management_system_stub) { migration_stub(:ExtManagementSystem) }
  let(:cloud_volume_stub) { migration_stub(:CloudVolume) }

  EMS_ROW_ENTRIES = [
    {:type => "ManageIQ::Providers::Openstack::CloudManager"},
    {:type => "ManageIQ::Providers::Amazon::CloudManager"},
    {:type => "ManageIQ::Providers::AnotherManager"}
  ]

  ROW_ENTRIES = [{
                   :ems      => EMS_ROW_ENTRIES[0],
                   :name     => "volume_1",
                   :type_in  => nil,
                   :type_out => 'ManageIQ::Providers::Openstack::CloudManager::CloudVolume'
                 },
                 {
                   :ems      => EMS_ROW_ENTRIES[1],
                   :name     => "volume_2",
                   :type_in  => 'ManageIQ::Providers::Openstack::CloudManager::CloudVolume',
                   :type_out => 'ManageIQ::Providers::Openstack::CloudManager::CloudVolume'
                 },
                 {
                   :ems      => EMS_ROW_ENTRIES[1],
                   :name     => "volume_3",
                   :type_in  => 'ManageIQ::Providers::Amazon::CloudManager::CloudVolume',
                   :type_out => 'ManageIQ::Providers::Amazon::CloudManager::CloudVolume'
                 },
                 {
                   :ems      => EMS_ROW_ENTRIES[1],
                   :name     => "volume_4",
                   :type_in  => nil,
                   :type_out => nil
                 },
                 {
                   :ems      => EMS_ROW_ENTRIES[2],
                   :name     => "volume_5",
                   :type_in  => 'ManageIQ::Providers::AnyManager::CloudVolume',
                   :type_out => 'ManageIQ::Providers::AnyManager::CloudVolume'
                 },
  ]

  migration_context :up do
    it "migrates a series of representative row" do
      EMS_ROW_ENTRIES.each do |x|
        x[:ems] = ext_management_system_stub.create!(:type => x[:type])
      end

      ROW_ENTRIES.each do |x|
        x[:cloud_volume] = cloud_volume_stub.create!(:type => x[:type_in], :ems_id => x[:ems][:ems].id, :name => x[:name])
      end

      migrate

      ROW_ENTRIES.each do |x|
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
      EMS_ROW_ENTRIES.each do |x|
        x[:ems] = ext_management_system_stub.create!(:type => x[:type])
      end

      ROW_ENTRIES.each do |x|
        x[:cloud_volume] = cloud_volume_stub.create!(:type => x[:type_out], :ems_id => x[:ems][:ems].id, :name => x[:name])
      end

      migrate

      ROW_ENTRIES.each do |x|
        expect(x[:cloud_volume].reload).to have_attributes(
                                             :type   => x[:type_in],
                                             :name   => x[:name],
                                             :ems_id => x[:ems][:ems][:id]
                                           )
      end
    end
  end
end

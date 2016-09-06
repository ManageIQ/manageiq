require "spec_helper"

describe ManageIQ::Providers::Openstack::CloudManager::CloudVolumeBackup do
  let(:ems) { FactoryGirl.create(:ems_openstack) }
  let(:tenant) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems) }

  let(:cloud_volume) do
    FactoryGirl.create(:cloud_volume_openstack,
                       :ext_management_system => ems,
                       :name                  => 'test',
                       :ems_ref               => 'one_id',
                       :cloud_tenant          => tenant)
  end

  let(:cloud_volume_backup) do
    FactoryGirl.create(:cloud_volume_backup_openstack,
                       :ext_management_system => ems,
                       :name                  => 'test backup',
                       :ems_ref               => 'two_id',
                       :cloud_volume          => cloud_volume)
  end

  it "handles cloud volume" do
    expect(cloud_volume_backup.cloud_volume).to eq(cloud_volume)
  end
end

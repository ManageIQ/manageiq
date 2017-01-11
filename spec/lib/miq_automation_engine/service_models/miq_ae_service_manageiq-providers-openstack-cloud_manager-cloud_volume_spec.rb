module MiqAeServiceCloudVolumeOpenstackSpec
  describe MiqAeMethodService::MiqAeServiceUser do
    let(:cloud_volume)         { FactoryGirl.create(:cloud_volume_openstack) }
    let(:service_cloud_volume) do
      MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager_CloudVolume.find(cloud_volume.id)
    end

    before do
      allow_any_instance_of(CloudVolume).to receive(:my_zone).and_return('default')
      allow(MiqServer).to receive(:my_zone).and_return('default')
      @base_queue_options = {
        :class_name  => cloud_volume.class.name,
        :instance_id => cloud_volume.id,
        :zone        => 'default',
        :role        => 'ems_operations',
        :task_id     => nil
      }
    end

    it "#backup_create async" do
      service_cloud_volume.backup_create('test backup', false)

      expect(MiqQueue.first).to have_attributes(
        @base_queue_options.merge(
          :method_name => 'backup_create',
          :args        => [{:name => "test backup", :incremental => false}])
      )
    end

    it "#backup_restore async" do
      service_cloud_volume.backup_restore('1234')

      expect(MiqQueue.first).to have_attributes(
        @base_queue_options.merge(
          :method_name => 'backup_restore',
          :args        => ["1234"])
      )
    end
  end
end

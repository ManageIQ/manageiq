require "spec_helper"
require 'MiqContainerGroup/MiqContainerGroup'

describe ManageIQ::Providers::Kubernetes::ContainerManager::Scanning::Job do
  context "SmartState Analysis Methods" do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_kubernetes, :hostname => 'hostname')
    end

    it "#initialize" do
      image = FactoryGirl.create(:container_image, :ext_management_system => @ems)
      job = @ems.scan_job_create(image.class.name, image.id)

      expect(MiqQueue.exists?(:method_name => 'signal',
                              :class_name  => 'Job',
                              :instance_id => job.id,
                              :role        => 'smartstate')).to be true
    end
  end
end

require "spec_helper"

describe ManageIQ::Providers::Vmware::InfraManager::Provision do
  context "::Placement" do
    before do
      ems      = FactoryGirl.create(:ems_vmware_with_authentication)
      template = FactoryGirl.create(:template_vmware, :ext_management_system => ems)
      vm       = FactoryGirl.create(:vm_vmware)
      @storage = FactoryGirl.create(:storage)
      @host    = FactoryGirl.create(:host, :ext_management_system => ems, :storages => [@storage])
      options  = {:src_vm_id => template.id}

      @task = FactoryGirl.create(:miq_provision_vmware, :source       => template,
                                                        :destination  => vm,
                                                        :request_type => 'template',
                                                        :state        => 'pending',
                                                        :status       => 'Ok',
                                                        :options      => options)
    end

    it "#manual_placement raise error" do
      @task.options[:placement_auto] = false
      expect { @task.send(:placement) }.to raise_error(MiqException::MiqProvisionError)
    end

    it "#manual_placement" do
      @task.options[:placement_host_name] = @host.id
      @task.options[:placement_ds_name]   = @storage.id
      @task.options[:placement_auto]      = false
      check
    end

    it "#automatic_placement" do
      @task.should_receive(:get_most_suitable_host_and_storage).and_return([@host, @storage])
      @task.options[:placement_auto] = true
      check
    end

    it "automate returns nothing" do
      @task.options[:placement_host_name] = @host.id
      @task.options[:placement_ds_name]   = @storage.id
      @task.should_receive(:get_most_suitable_host_and_storage).and_return([nil, nil])
      @task.options[:placement_auto] = true
      check
    end

    def check
      host, storage = @task.send(:placement)
      host.should eql(@host)
      storage.should eql(@storage)
    end
  end
end

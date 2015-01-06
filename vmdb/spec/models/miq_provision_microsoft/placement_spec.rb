require "spec_helper"

describe MiqProvisionMicrosoft do
  context "::Placement" do
    before do
      ems      = FactoryGirl.create(:ems_microsoft_with_authentication)
      template = FactoryGirl.create(:template_microsoft, :ext_management_system => ems)
      vm       = FactoryGirl.create(:vm_microsoft)
      @host    = FactoryGirl.create(:host_microsoft, :ext_management_system => ems)
      @storage = FactoryGirl.create(:storage)
      options  = {:src_vm_id => template.id}

      @task = FactoryGirl.create(
        :miq_provision_microsoft,
        :source      => template,
        :destination => vm,
        :state       => 'pending',
        :status      => 'Ok',
        :options     => options)
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

    def check
      @task.send(:placement)
      @task.options[:dest_host].should eql([@host.id, @host.name])
    end
  end
end

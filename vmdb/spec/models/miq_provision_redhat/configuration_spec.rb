require "spec_helper"
require "ovirt"

describe MiqProvisionRedhat::Configuration do
  before do
    ems       = FactoryGirl.create(:ems_redhat_with_authentication)
    template  = FactoryGirl.create(:template_redhat, :ext_management_system => ems)
    vm        = FactoryGirl.create(:vm_redhat)
    options   = {:src_vm_id => template.id}
    @task     = FactoryGirl.create(:miq_provision_redhat,
                                   :source      => template,
                                   :destination => vm,
                                   :state       => 'pending',
                                   :status      => 'Ok',
                                   :options     => options)
    @task.stub(:dest_cluster => FactoryGirl.create(:ems_cluster, :ext_management_system => ems))

    @rhevm_vm = double('rhevm_vm').as_null_object
    @task.stub(:get_provider_destination => @rhevm_vm)
  end

  context "#attach_floppy_payload" do
    it "should attach floppy if customization template provided" do
      script = '#cloudinit'
      template = FactoryGirl.create(:customization_template_cloud_init, :script => script)

      template_options = {'key' => 'value'}
      @task.should_receive(:prepare_customization_template_substitution_options).and_return(template_options)

      @task.options[:customization_template_id] = template.id
      @rhevm_vm.should_receive(:attach_floppy).with(template.default_filename => script)

      @task.attach_floppy_payload
    end
  end

  context "#configure_container" do
    it "should configure the memory reserve if provided" do
      memory_reserve_in_mb = 1024
      @task.options[:memory_reserve] = memory_reserve_in_mb
      @rhevm_vm.should_receive(:memory_reserve=).with(memory_reserve_in_mb.megabytes)
      @task.configure_container
    end
  end
end

require "spec_helper"
require "ovirt"

describe ManageIQ::Providers::Redhat::InfraManager::Provision::Configuration do
  let(:cust_template) { FactoryGirl.create(:customization_template_cloud_init, :script => '#some_script') }
  let(:ems)           { FactoryGirl.create(:ems_redhat_with_authentication) }
  let(:host)          { FactoryGirl.create(:host_redhat) }
  let(:rhevm_vm)      { instance_double("Ovirt::Vm") }
  let(:task)          { FactoryGirl.create(:miq_provision_redhat, :state => 'pending', :status => 'Ok', :options => {:src_vm_id => template.id}) }
  let(:template)      { FactoryGirl.create(:template_redhat, :ext_management_system => ems) }
  let(:vm)            { FactoryGirl.create(:vm_redhat) }

  before { task.stub(:get_provider_destination => rhevm_vm) }

  context "#attach_floppy_payload" do
    it "should attach floppy if customization template provided" do
      task.options[:customization_template_id] = cust_template.id

      expect(task).to     receive(:prepare_customization_template_substitution_options).and_return('key' => 'value')
      expect(rhevm_vm).to receive(:attach_floppy).with(cust_template.default_filename => '#some_script')

      task.attach_floppy_payload
    end
  end

  context "#configure_cloud_init" do
    it "should configure cloudinit if customization template provided" do
      task.options[:customization_template_id] = cust_template.id

      expect(task).to     receive(:prepare_customization_template_substitution_options).and_return('key' => 'value')
      expect(rhevm_vm).to receive(:cloud_init=).with('#some_script')

      task.configure_cloud_init
    end
  end

  context "#configure_container" do
    it "with options set" do
      task.options[:cpu_cores_per_socket] = 4
      task.options[:dest_host]            = host.id
      task.options[:memory_reserve]       = 1024
      task.options[:number_of_sockets]    = 2
      task.options[:vm_description]       = "abc"
      task.options[:vm_memory]            = 2048

      expect(rhevm_vm).to receive(:description=).with("abc")
      expect(rhevm_vm).to receive(:memory=).with(2147483648)
      expect(rhevm_vm).to receive(:memory_reserve=).with(1073741824)
      expect(rhevm_vm).to receive(:cpu_topology=).with(:cores => 4, :sockets => 2)
      expect(rhevm_vm).to receive(:host_affinity=).with(host.ems_ref)

      task.configure_container
    end

    it "without options" do
      expect(rhevm_vm).to receive(:description=).with(nil)
      expect(rhevm_vm).to receive(:cpu_topology=).with(:cores => 1, :sockets => 1)

      task.configure_container
    end
  end
end

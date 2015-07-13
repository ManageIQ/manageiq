require "spec_helper"

describe MiqProvisionOpenstack::Configuration do
  context "#configure_network_adapters" do
    before do
      @ems      = FactoryGirl.create(:ems_openstack_with_authentication)
      @template = FactoryGirl.create(:template_openstack, :ext_management_system => @ems)
      @vm       = FactoryGirl.create(:vm_openstack)
      @net1     = FactoryGirl.create(:cloud_network)
      @net2     = FactoryGirl.create(:cloud_network)

      @task = FactoryGirl.create(:miq_provision_openstack,
                                 :source      => @template,
                                 :destination => @vm,
                                 :state       => 'pending',
                                 :status      => 'Ok',
                                 :options     => {
                                   :src_vm_id     => @template.id,
                                   :cloud_network => [@net1.id, @net1.name]
                                 }
      )
      @task.stub(:miq_request => double("MiqRequest").as_null_object)
    end

    it "sets nic from dialog" do
      @task.configure_network_adapters

      expect(@task.options[:networks]).to eq([{"net_id" => @net1.ems_ref}])
    end

    it "sets nic from dialog with additional nic from automate" do
      @task.options[:networks] = [nil, {:network_id => @net2.id}]

      @task.configure_network_adapters

      expect(@task.options[:networks]).to eq([{"net_id" => @net1.ems_ref}, {"net_id" => @net2.ems_ref}])
    end

    it "override nic from dialog with nic from automate" do
      @task.options[:networks] = [{:network_id => @net2.id}]

      @task.configure_network_adapters

      expect(@task.options[:networks]).to eq([{"net_id" => @net2.ems_ref}])
    end

    it "ensure there are no blanks in the array" do
      @task.options[:networks] = [nil, nil, {:network_id => @net2.id}]

      @task.configure_network_adapters

      expect(@task.options[:networks]).to eq([{"net_id" => @net1.ems_ref}, {"net_id" => @net2.ems_ref}])
    end
  end
end

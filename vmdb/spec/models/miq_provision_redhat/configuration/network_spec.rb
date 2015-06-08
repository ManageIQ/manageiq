require "spec_helper"
require "ovirt"

describe MiqProvisionRedhat::Configuration::Network do
  let(:mac_address)   { "mac_address" }
  let(:network_id)    { "network1-id" }
  let(:network_name)  { "network1-name" }
  let(:rhevm_cluster) { double("Ovirt::Cluster", :find_network_by_name => {:id => network_id}) }
  let(:rhevm_nic1)    { {:name => "nic1", :network => {:id => network_id}, :mac => {:address => mac_address}} }
  let(:rhevm_nic2)    { {:name => "nic2", :network => {:id => "network2-id"}} }
  let(:set_vlan)      { @task.options[:vlan] = [network_name, network_name] }
  let(:ems)           { FactoryGirl.create(:ems_redhat_with_authentication) }
  let(:ems_cluster)   { FactoryGirl.create(:ems_cluster, :ext_management_system => ems) }
  let(:template)      { FactoryGirl.create(:template_redhat, :ext_management_system => ems) }
  let(:rhevm_vm)      { FactoryGirl.create(:vm_redhat) }

  before do
    @task = FactoryGirl.create(:miq_provision_redhat,
                               :source      => template,
                               :destination => rhevm_vm,
                               :state       => 'pending',
                               :status      => 'Ok',
                               :options     => {:src_vm_id => template.id}
    )
    @task.stub(
      :dest_cluster             => ems_cluster,
      :get_provider_destination => rhevm_vm
    )

    rhevm_vm.stub(:nics => [rhevm_nic1, rhevm_nic2])
    Ovirt::Cluster.stub(:find_by_href => rhevm_cluster)
  end

  context "#configure_network_adapters" do
    context "add second NIC in automate" do
      before do
        @task.options[:networks] = [nil, {:network => network_name}]
      end

      it "first NIC from dialog" do
        set_vlan
        rhevm_nic1.should_receive(:apply_options!)
        rhevm_nic2.should_receive(:apply_options!)

        @task.configure_network_adapters

        expect(@task.options[:networks]).to eq([
          {:network => network_name, :mac_address => nil},
          {:network => network_name}
        ])
      end

      it "no NIC from dialog" do
        rhevm_nic1.should_receive(:destroy)
        rhevm_nic2.should_receive(:apply_options!)

        @task.configure_network_adapters
      end
    end

    it "dialog NIC only" do
      set_vlan

      rhevm_nic1.should_receive(:apply_options!)
      rhevm_nic2.should_receive(:destroy)

      @task.configure_network_adapters
    end

    it "no NICs" do
      @task.configure_network_adapters
    end

    context "update NICs" do
      it "should update an existing adapter's network" do
        @task.options[:networks] = [{:network => network_name}]

        rhevm_vm.should_receive(:nics).and_return([rhevm_nic1])
        rhevm_nic1.should_receive(:apply_options!).with(:name => "nic1", :network_id => network_id)

        @task.configure_network_adapters
      end

      it "should update an existing adapter's MAC address" do
        @task.options[:networks] = [{:mac_address => mac_address}]

        rhevm_vm.should_receive(:nics).and_return([rhevm_nic1])
        rhevm_nic1.should_receive(:apply_options!).with(
          :name        => "nic1",
          :network_id  => network_id,
          :mac_address => mac_address
        )

        @task.configure_network_adapters
      end
    end

    it "should create a new adapter with an optional MAC address" do
      @task.options[:networks] = [{:network => network_name, :mac_address => mac_address}]

      rhevm_vm.should_receive(:nics).and_return([])
      rhevm_vm.should_receive(:create_nic).with(
        :name        => 'nic1',
        :network_id  => network_id,
        :mac_address => mac_address
      )

      @task.configure_network_adapters
    end
  end

  context "#get_mac_address_of_nic_on_requested_vlan" do
    it "NIC found" do
      expect(@task.get_mac_address_of_nic_on_requested_vlan).to eq(mac_address)
    end

    it "NIC not found" do
      rhevm_nic1[:network][:id] = "network2-id"

      expect(@task.get_mac_address_of_nic_on_requested_vlan).to eq(nil)
    end
  end
end

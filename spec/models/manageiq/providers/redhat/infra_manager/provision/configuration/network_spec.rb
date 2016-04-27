require "ovirt"

describe ManageIQ::Providers::Redhat::InfraManager::Provision::Configuration::Network do
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
  let(:ovirt_service) { double("Ovirt::Service", :api_path => "/api") }

  before do
    @task = FactoryGirl.create(:miq_provision_redhat,
                               :source      => template,
                               :destination => rhevm_vm,
                               :state       => 'pending',
                               :status      => 'Ok',
                               :options     => {:src_vm_id => template.id}
                              )
    allow(@task).to receive_messages(
      :dest_cluster             => ems_cluster,
      :get_provider_destination => rhevm_vm
    )

    allow(Ovirt::Service).to receive_messages(:new => ovirt_service)

    allow(rhevm_vm).to receive_messages(:nics => [rhevm_nic1, rhevm_nic2])
    allow(Ovirt::Cluster).to receive_messages(:find_by_href => rhevm_cluster)
  end

  context "#configure_network_adapters" do
    context "add second NIC in automate" do
      before do
        @task.options[:networks] = [nil, {:network => network_name}]
      end

      it "first NIC from dialog" do
        set_vlan
        expect(rhevm_nic1).to receive(:apply_options!)
        expect(rhevm_nic2).to receive(:apply_options!)

        @task.configure_network_adapters

        expect(@task.options[:networks]).to eq([
          {:network => network_name, :mac_address => nil},
          {:network => network_name}
        ])
      end

      it "no NIC from dialog" do
        expect(rhevm_nic1).to receive(:destroy)
        expect(rhevm_nic2).to receive(:apply_options!)

        @task.configure_network_adapters
      end
    end

    it "dialog NIC only" do
      set_vlan

      expect(rhevm_nic1).to receive(:apply_options!)
      expect(rhevm_nic2).to receive(:destroy)

      @task.configure_network_adapters
    end

    it "no NICs" do
      @task.configure_network_adapters
    end

    context "update NICs" do
      it "should update an existing adapter's network" do
        @task.options[:networks] = [{:network => network_name}]

        expect(rhevm_vm).to receive(:nics).and_return([rhevm_nic1])
        expect(rhevm_nic1).to receive(:apply_options!).with(:name => "nic1", :network_id => network_id)

        @task.configure_network_adapters
      end

      it "should update an existing adapter's MAC address" do
        @task.options[:networks] = [{:mac_address => mac_address}]

        expect(rhevm_vm).to receive(:nics).and_return([rhevm_nic1])
        expect(rhevm_nic1).to receive(:apply_options!).with(
          :name        => "nic1",
          :network_id  => network_id,
          :mac_address => mac_address
        )

        @task.configure_network_adapters
      end
    end

    it "should create a new adapter with an optional MAC address" do
      @task.options[:networks] = [{:network => network_name, :mac_address => mac_address}]

      expect(rhevm_vm).to receive(:nics).and_return([])
      expect(rhevm_vm).to receive(:create_nic).with(
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

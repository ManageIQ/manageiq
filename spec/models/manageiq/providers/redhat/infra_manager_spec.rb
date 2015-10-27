require "spec_helper"

describe ManageIQ::Providers::Redhat::InfraManager do
  it ".ems_type" do
    described_class.ems_type.should == 'rhevm'
  end

  it ".description" do
    described_class.description.should == 'Red Hat Enterprise Virtualization Manager'
  end

  describe ".metrics_collector_queue_name" do
    it "returns the correct queue name" do
      worker_queue = ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker.default_queue_name
      expect(described_class.metrics_collector_queue_name).to eq(worker_queue)
    end
  end

  it "rhevm_metrics_connect_options" do
    h = FactoryGirl.create(:ems_redhat, :hostname => "h")
    h.rhevm_metrics_connect_options[:host].should == "h"
  end

  it "rhevm_metrics_connect_options overrides" do
    h = FactoryGirl.create(:ems_redhat, :hostname => "h")
    h.rhevm_metrics_connect_options(:hostname => "i")[:host].should == "i"
  end

  context "#vm_reconfigure" do
    before do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems  = FactoryGirl.create(:ems_redhat_with_authentication, :zone => zone)
      @hw   = FactoryGirl.create(:hardware, :memory_mb => 1024, :cpu_sockets => 2, :cpu_cores_per_socket => 1)
      @vm   = FactoryGirl.create(:vm_redhat, :ext_management_system => @ems)

      @cores_per_socket = 2
      @num_of_sockets   = 3
      @total_mem_in_mb  = 4096

      @spec             = {"memoryMB"          => @total_mem_in_mb,
                           "numCPUs"           => @cores_per_socket * @num_of_sockets,
                           "numCoresPerSocket" => @cores_per_socket}

      @rhevm_vm = double('rhevm_vm').as_null_object
      @vm.stub(:with_provider_object).and_yield(@rhevm_vm)
    end

    it "cpu_topology=" do
      @rhevm_vm.should_receive(:cpu_topology=).with(:cores => @cores_per_socket, :sockets => @num_of_sockets)
      @ems.vm_reconfigure(@vm, :spec => @spec)
    end

    it "memory=" do
      @rhevm_vm.should_receive(:memory=).with(@total_mem_in_mb.megabytes)
      @ems.vm_reconfigure(@vm, :spec => @spec)
    end
  end
end

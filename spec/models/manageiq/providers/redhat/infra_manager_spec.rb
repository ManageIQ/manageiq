describe ManageIQ::Providers::Redhat::InfraManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('rhevm')
  end

  it ".description" do
    expect(described_class.description).to eq('Red Hat Enterprise Virtualization Manager')
  end

  describe ".metrics_collector_queue_name" do
    it "returns the correct queue name" do
      worker_queue = ManageIQ::Providers::Redhat::InfraManager::MetricsCollectorWorker.default_queue_name
      expect(described_class.metrics_collector_queue_name).to eq(worker_queue)
    end
  end

  describe "rhevm_metrics_connect_options" do
    let(:ems) { FactoryGirl.create(:ems_redhat, :hostname => "some.thing.tld") }

    it "rhevm_metrics_connect_options fetches configuration and allows overrides" do
      expect(ems.rhevm_metrics_connect_options[:host]).to eq("some.thing.tld")
      expect(ems.rhevm_metrics_connect_options({:hostname => "different.tld"})[:host])
        .to eq("different.tld")
    end
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

      @rhevm_vm_attrs = double('rhevm_vm_attrs')
      allow(@rhevm_vm_attrs).to receive(:fetch_path).with(:memory).and_return(@total_mem_in_mb.megabytes)
      @rhevm_vm = double('rhevm_vm')
      allow(@rhevm_vm).to receive(:attributes).and_return(@rhevm_vm_attrs)
      allow(@vm).to receive(:with_provider_object).and_yield(@rhevm_vm)
    end

    it "cpu_topology=" do
      spec = {
        "numCPUs"           => @cores_per_socket * @num_of_sockets,
        "numCoresPerSocket" => @cores_per_socket
      }

      expect(@rhevm_vm).to receive(:cpu_topology=).with(:cores => @cores_per_socket, :sockets => @num_of_sockets)
      @ems.vm_reconfigure(@vm, :spec => spec)
    end

    it "memory=" do
      spec = {
        "memoryMB" => @total_mem_in_mb
      }

      expect(@rhevm_vm).to receive(:memory=).with(@total_mem_in_mb.megabytes)
      expect(@rhevm_vm).to receive(:memory_reserve=).with(@total_mem_in_mb.megabytes)
      @ems.vm_reconfigure(@vm, :spec => spec)
    end
  end

  context ".make_ems_ref" do
    it "removes the /ovirt-engine prefix" do
      expect(described_class.make_ems_ref("/ovirt-engine/api/vms/123")).to eq("/api/vms/123")
    end

    it "does not remove the /api prefix" do
      expect(described_class.make_ems_ref("/api/vms/123")).to eq("/api/vms/123")
    end
  end

  context ".extract_ems_ref_id" do
    it "extracts the resource ID from the href" do
      expect(described_class.extract_ems_ref_id("/ovirt-engine/api/vms/123")).to eq("123")
    end
  end

  context "api versions" do
    let(:ems) { FactoryGirl.create(:ems_redhat) }
    context "#supported_api_versions" do
      it "returns the supported api versions" do
        expect(ems.supported_api_versions).to match_array([3])
      end
    end

    context "#supports_api_version?" do
      it "returns the supported api versions" do
        allow(ems).to receive(:supported_api_versions).and_return([3])
        expect(ems.supports_api_version?(3)).to eq(true)
        expect(ems.supports_api_version?(6)).to eq(false)
      end
    end
  end
end

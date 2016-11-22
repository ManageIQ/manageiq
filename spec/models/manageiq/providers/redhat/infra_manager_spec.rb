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
      expect(ems.rhevm_metrics_connect_options(:hostname => "different.tld")[:host])
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

      @rhevm_vm_attrs = double('rhevm_vm_attrs')
      allow(@rhevm_vm_attrs).to receive(:fetch_path).with(:name).and_return('myvm')
      allow(@rhevm_vm_attrs).to receive(:fetch_path).with(:memory).and_return(4.gigabytes)
      allow(@rhevm_vm_attrs).to receive(:fetch_path).with(:memory_policy, :guaranteed).and_return(2.gigabytes)
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

    it 'updates the current and persistent configuration if the VM is up' do
      spec = {
        'memoryMB' => 8.gigabytes / 1.megabyte
      }
      allow(@rhevm_vm_attrs).to receive(:fetch_path).with(:status, :state).and_return('up')
      expect(@rhevm_vm).to receive(:update_memory).with(8.gigabytes, 2.gigabytes, :next_run => true)
      expect(@rhevm_vm).to receive(:update_memory).with(8.gigabytes, nil, :next_run => false)
      @ems.vm_reconfigure(@vm, :spec => spec)
    end

    it 'updates only the persistent configuration when the VM is down' do
      spec = {
        'memoryMB' => 8.gigabytes / 1.megabyte
      }
      allow(@rhevm_vm_attrs).to receive(:fetch_path).with(:status, :state).and_return('down')
      expect(@rhevm_vm).to receive(:update_memory).with(8.gigabytes, 2.gigabytes)
      @ems.vm_reconfigure(@vm, :spec => spec)
    end

    it 'adjusts the increased memory to the next 256 MiB multiple if the VM is up' do
      spec = {
        'memoryMB' => 8.gigabytes / 1.megabyte + 1
      }
      adjusted = 8.gigabytes + 256.megabytes
      allow(@rhevm_vm_attrs).to receive(:fetch_path).with(:status, :state).and_return('up')
      expect(@rhevm_vm).to receive(:update_memory).with(adjusted, 2.gigabytes, :next_run => true)
      expect(@rhevm_vm).to receive(:update_memory).with(adjusted, nil, :next_run => false)
      @ems.vm_reconfigure(@vm, :spec => spec)
    end

    it 'adjusts reduced memory to the next 256 MiB multiple if the VM is up' do
      spec = {
        'memoryMB' => 8.gigabytes / 1.megabyte - 1
      }
      adjusted = 8.gigabytes
      allow(@rhevm_vm_attrs).to receive(:fetch_path).with(:status, :state).and_return('up')
      expect(@rhevm_vm).to receive(:update_memory).with(adjusted, 2.gigabytes, :next_run => true)
      expect(@rhevm_vm).to receive(:update_memory).with(adjusted, nil, :next_run => false)
      @ems.vm_reconfigure(@vm, :spec => spec)
    end

    it 'adjusts the guaranteed memory if it is larger than the virtual memory if the VM is up' do
      spec = {
        'memoryMB' => 1.gigabyte / 1.megabyte
      }
      adjusted = 1.gigabyte
      allow(@rhevm_vm_attrs).to receive(:fetch_path).with(:status, :state).and_return('up')
      expect(@rhevm_vm).to receive(:update_memory).with(1.gigabyte, adjusted, :next_run => true)
      expect(@rhevm_vm).to receive(:update_memory).with(1.gigabyte, nil, :next_run => false)
      @ems.vm_reconfigure(@vm, :spec => spec)
    end

    it 'adjusts the guaranteed memory if it is larger than the virtual memory if the VM is down' do
      spec = {
        'memoryMB' => 1.gigabyte / 1.megabyte
      }
      adjusted = 1.gigabyte
      allow(@rhevm_vm_attrs).to receive(:fetch_path).with(:status, :state).and_return('down')
      expect(@rhevm_vm).to receive(:update_memory).with(1.gigabyte, adjusted)
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
    require 'ovirtsdk4'
    let(:ems) { FactoryGirl.create(:ems_redhat_with_authentication) }
    subject(:supported_api_versions) { ems.supported_api_versions }
    context "#supported_api_versions" do
      before(:each) do
        Rails.cache.delete(ems.cache_key)
        Rails.cache.write(ems.cache_key, cached_api_versions)
      end

      context "when no cached supported_api_versions" do
        let(:cached_api_versions) { nil }
        it 'calls the OvirtSDK4::Probe.probe' do
          expect(OvirtSDK4::Probe).to receive(:probe).and_return([])
          supported_api_versions
        end

        it 'properly parses ProbeResults' do
          allow(OvirtSDK4::Probe).to receive(:probe)
            .and_return([OvirtSDK4::ProbeResult.new(:version => '3'),
                         OvirtSDK4::ProbeResult.new(:version => '4')])
          expect(supported_api_versions).to match_array(%w(3 4))
        end
      end

      context "when cache of supported_api_versions is stale" do
        let(:cached_api_versions) do
          {
            :created_at => Time.now.utc,
            :value      => [3]
          }
        end

        before(:each) do
          allow(ems).to receive(:last_refresh_date)
            .and_return(cached_api_versions[:created_at] + 1.day)
        end

        it 'calls the OvirtSDK4::Probe.probe' do
          expect(OvirtSDK4::Probe).to receive(:probe).and_return([])
          supported_api_versions
        end
      end

      context "when cache of supported_api_versions available" do
        let(:cached_api_versions) do
          {
            :created_at => Time.now.utc,
            :value      => [3]
          }
        end

        before(:each) do
          allow(ems).to receive(:last_refresh_date)
            .and_return(cached_api_versions[:created_at] - 1.day)
        end

        it 'returns from cache' do
          expect(supported_api_versions).to match_array([3])
        end
      end
    end

    describe "#supports_the_api_version?" do
      it "returns the supported api versions" do
        allow(ems).to receive(:supported_api_versions).and_return([3])
        expect(ems.supports_the_api_version?(3)).to eq(true)
        expect(ems.supports_the_api_version?(6)).to eq(false)
      end
    end
  end

  context "supported features" do
    let(:ems) { FactoryGirl.create(:ems_redhat) }
    let(:supported_api_versions) { [3, 4] }
    context "#process_api_features_support" do
      before(:each) do
        allow(SupportsFeatureMixin).to receive(:guard_queryable_feature).and_return(true)
        allow(described_class).to receive(:api_features)
          .and_return('3' => %w(feature1 feature3), '4' => %w(feature2 feature3))
        described_class.process_api_features_support
        allow(ems).to receive(:supported_api_versions).and_return(supported_api_versions)
      end

      context "no versions supported" do
        let(:supported_api_versions) { [] }
        it 'supports the right features' do
          expect(ems.supports_feature1?).to be_falsey
          expect(ems.supports_feature2?).to be_falsey
          expect(ems.supports_feature3?).to be_falsey
        end
      end

      context "version 3 supported" do
        let(:supported_api_versions) { [3] }
        it 'supports the right features' do
          expect(ems.supports_feature1?).to be_truthy
          expect(ems.supports_feature2?).to be_falsey
          expect(ems.supports_feature3?).to be_truthy
        end
      end

      context "version 4 supported" do
        let(:supported_api_versions) { [4] }
        it 'supports the right features' do
          expect(ems.supports_feature1?).to be_falsey
          expect(ems.supports_feature2?).to be_truthy
          expect(ems.supports_feature3?).to be_truthy
        end
      end

      context "all versions supported" do
        let(:supported_api_versions) { [3, 4] }
        it 'supports the right features' do
          expect(ems.supports_feature1?).to be_truthy
          expect(ems.supports_feature2?).to be_truthy
          expect(ems.supports_feature3?).to be_truthy
        end
      end
    end
  end
end

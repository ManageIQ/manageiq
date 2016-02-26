describe ManageIQ::Providers::Vmware::InfraManager::Vm::Reconfigure do
  let(:vm) { vm = FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :virtual_hw_version => "07")) }

  it "#reconfigurable?" do
    expect(vm.reconfigurable?).to be_truthy
  end

  context "#max_total_vcpus" do
    before do
      @host = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :cpu_total_cores => 160))
      vm.host = @host
    end
    subject { vm.max_total_vcpus }

    context "vitural_hw_version" do
      it "07" do
        expect(subject).to eq(8)
      end

      it "08" do
        vm.hardware.update_attributes(:virtual_hw_version => "08")
        expect(subject).to eq(32)
      end

      it "09" do
        vm.hardware.update_attributes(:virtual_hw_version => "09")
        expect(subject).to eq(64)
      end

      it "10" do
        vm.hardware.update_attributes(:virtual_hw_version => "10")
        expect(subject).to eq(64)
      end
    end

    it "small host logical cpus" do
      @host.hardware.update_attributes(:cpu_total_cores => 4)
      expect(subject).to eq(4)
    end

    it "big host logical cpus" do
      expect(subject).to eq(8)
    end
  end

  context "#build_config_spec" do
    let(:options ) { {:vm_memory => '1024', :number_of_cpus => '8', :cores_per_socket => '2'} }
    subject { vm.build_config_spec(options) }

    it "memoryMB" do
      expect(subject["memoryMB"]).to eq(1024)
    end

    it "numCPUs" do
      expect(subject["numCPUs"]).to eq(8)
    end

    context "numCoresPerSocket" do
      it "vm_vmware virtual_hw_version = 07" do
        expect(subject["extraConfig"]).to eq([{"key" => "cpuid.coresPerSocket", "value" => "2"}])
      end

      it "vm_vmware virtual_hw_version != 07" do
        vm.hardware.update_attributes(:virtual_hw_version => "08")
        expect(subject["numCoresPerSocket"]).to eq(2)
      end
    end
  end
end

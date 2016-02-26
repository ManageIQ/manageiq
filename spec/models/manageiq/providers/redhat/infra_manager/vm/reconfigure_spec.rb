describe ManageIQ::Providers::Redhat::InfraManager::Vm::Reconfigure do
  let(:vm) { FactoryGirl.create(:vm_redhat) }

  it "#reconfigurable?" do
    expect(vm.reconfigurable?).to be_truthy
  end

  it "#max_total_vcpus" do
    expect(vm.max_total_vcpus).to eq(160)
  end

  it "#max_cpu_cores_per_socket" do
    expect(vm.max_cpu_cores_per_socket).to eq(16)
  end

  it "#max_vcpus" do
    expect(vm.max_vcpus).to eq(16)
  end

  it "#max_memory_mb" do
    expect(vm.max_memory_mb).to eq(2.terabyte / 1.megabyte)
  end

  context "#build_config_spec" do
    before do
      @options = {:vm_memory => '1024', :number_of_cpus => '8', :cores_per_socket => '2'}
      @vm      = FactoryGirl.create(:vm_redhat, :hardware => FactoryGirl.create(:hardware))
    end
    subject { @vm.build_config_spec(@options) }

    it "memoryMB" do
      expect(subject["memoryMB"]).to eq(1024)
    end

    it "numCPUs" do
      expect(subject["numCPUs"]).to eq(8)
    end

    it "numCoresPerSocket" do
      expect(subject["numCoresPerSocket"]).to eq(2)
    end
  end
end

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
end

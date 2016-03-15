describe ManageIQ::Providers::Microsoft::InfraManager::Vm do
  context "#active_proxy?" do
    let(:vm_microsoft) { ManageIQ::Providers::Microsoft::InfraManager::Vm.new }

    it "returns true" do
      expect(vm_microsoft.has_active_proxy?).to eq(true)
    end
  end

  context "#has_proxy?" do
    let(:vm_microsoft) { ManageIQ::Providers::Microsoft::InfraManager::Vm.new }

    it "returns true" do
      expect(vm_microsoft.has_proxy?).to eq(true)
    end
  end

  context "#proxies4job" do
    before do
      @vm_microsoft = ManageIQ::Providers::Microsoft::InfraManager::Vm.new
      allow(MiqServer).to receive(:my_server).and_return("default")
      @proxies = @vm_microsoft.proxies4job
    end

    it "has the correct message" do
      expect(@proxies[:message]).to eq('Perform SmartState Analysis on this VM')
    end

    it "returns the default proxy" do
      expect(@proxies[:proxies].first).to eq('default')
    end
  end
end

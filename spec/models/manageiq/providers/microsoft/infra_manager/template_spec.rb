describe ManageIQ::Providers::Microsoft::InfraManager::Template do
  context "#active_proxy?" do
    let(:template_microsoft) { ManageIQ::Providers::Microsoft::InfraManager::Template.new }

    it "returns true" do
      expect(template_microsoft.has_active_proxy?).to eq(true)
    end
  end

  context "#has_proxy?" do
    let(:template_microsoft) { ManageIQ::Providers::Microsoft::InfraManager::Template.new }

    it "returns true" do
      expect(template_microsoft.has_proxy?).to eq(true)
    end
  end

  context "#proxies4job" do
    before do
      @template_microsoft = ManageIQ::Providers::Microsoft::InfraManager::Template.new
      allow(MiqServer).to receive(:my_server).and_return("default")
      @proxies = @template_microsoft.proxies4job
    end

    it "has the correct message" do
      expect(@proxies[:message]).to eq('Perform SmartState Analysis on this VM')
    end

    it "returns the default proxy" do
      expect(@proxies[:proxies].first).to eq('default')
    end
  end
end

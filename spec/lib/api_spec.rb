describe Api do
  context "model_to_collection" do
    it "support classes" do
      expect(Api.model_to_collection(Vm)).to eq(:vms)
    end

    it "support class names" do
      expect(Api.model_to_collection("Tenant")).to eq(:tenants)
    end

    it "returns nil for unsupported classes" do
      expect(Api.model_to_collection("BogusClassName")).to be_nil
    end
  end
end

describe ChargebackRate do
  context "#validate_rate_type" do
    it "handles valid types" do
      [:compute, :storage, 'compute', 'storage', 'Compute', 'Storage'].each do |type|
        expect { ChargebackRate.validate_rate_type(type) }.not_to raise_error
      end
    end

    it "raises error for invalid type" do
      expect { ChargebackRate.validate_rate_type(:bogus) }.to raise_error(RuntimeError, "Chargeback rate type 'bogus' is not supported")
    end
  end
end

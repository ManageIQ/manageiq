require_migration

describe TransferRateValueToTiers do
  let(:chargeback_rate_detail_stub) { migration_stub(:ChargebackRateDetail) }

  migration_context :up do
    it "transfers rate value" do
      cbrd = chargeback_rate_detail_stub.create(:rate => 1.0)
      migrate
      cbrd.reload
      expect(cbrd.chargeback_tiers.length).to eq(1)
      expect(cbrd.chargeback_tiers[0].fixed_rate).to eq(0.0)
      expect(cbrd.chargeback_tiers[0].variable_rate).to eq(1.0)
    end
  end
end

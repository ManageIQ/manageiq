describe ChargebackRate do
  describe "#rate_details_relevant_to" do
    let(:count_hourly_variable_tier_rate) { {:variable_rate => '10'} }

    let!(:chargeback_rate) do
      FactoryBot.create(:chargeback_rate, :detail_params => {:chargeback_rate_detail_cpu_cores_allocated => {:tiers => [count_hourly_variable_tier_rate]}})
    end

    it "skips cpu_cores_allocated column" do
      expect(chargeback_rate.rate_details_relevant_to(['total_cost'].to_set, ChargebackVm.attribute_names)).to be_empty
    end
  end

  context ".validate_rate_type" do
    it "handles valid types" do
      [:compute, :storage, 'compute', 'storage', 'Compute', 'Storage'].each do |type|
        expect { ChargebackRate.validate_rate_type(type) }.not_to raise_error
      end
    end

    it "raises error for invalid type" do
      expect { ChargebackRate.validate_rate_type(:bogus) }.to raise_error(RuntimeError, "Chargeback rate type 'bogus' is not supported")
    end
  end

  context "#assigned?" do
    it "when unassigned" do
      cbr = FactoryBot.create(:chargeback_rate)
      expect(cbr).to_not be_assigned
    end

    it "when assigned" do
      cbr = FactoryBot.create(:chargeback_rate)
      host = FactoryBot.create(:host)
      cbr.assign_to_objects(host)
      expect(cbr).to be_assigned
    end
  end

  context "#destroy" do
    it "when unassigned" do
      cbr = FactoryBot.create(:chargeback_rate)

      cbr.destroy

      expect(cbr).to be_destroyed
      expect(cbr.errors.count).to be(0)
    end

    it "when assigned" do
      cbr  = FactoryBot.create(:chargeback_rate, :description => "Unassigned Rate")
      host = FactoryBot.create(:host)
      cbr.assign_to_objects(host)

      cbr.destroy

      expect(cbr).to_not be_destroyed

      expect(cbr.errors.count).to be(1)
      expect(cbr.errors.first).to include("rate is assigned and cannot be deleted")
    end

    it "when default" do
      cbr = FactoryBot.create(:chargeback_rate, :description => "Default", :default => true)
      cbr.destroy
      expect(cbr).to_not be_destroyed
      expect(cbr.errors.count).to be(1)
      expect(cbr.errors.first).to include("default rate cannot be deleted")
    end

    it "when non-default with default description" do
      cbr = FactoryBot.create(:chargeback_rate, :description => "Default Container Image Rate", :default => false)
      cbr.destroy
      expect(cbr).to_not be_destroyed
      expect(cbr.errors.count).to be(1)
      expect(cbr.errors.first).to include("default rate cannot be deleted")
    end

    it "when non-default" do
      cbr = FactoryBot.create(:chargeback_rate, :description => "Non-default", :default => false)
      cbr.destroy
      expect(cbr).to be_destroyed
      expect(cbr.errors.count).to be(0)
    end
  end

  describe '#currency_symbol' do
    let(:rate) { FactoryBot.build(:chargeback_rate, :chargeback_rate_details => details) }
    subject { rate.currency_symbol }

    context 'when there are no rate details' do
      let(:details) { [] }
      it { is_expected.to be_nil }
    end

    context 'when there are valid rate details' do
      let(:symbol) { '฿' }
      let(:currency) { FactoryBot.create(:currency, :symbol => symbol) }
      let(:field) { FactoryBot.create(:chargeable_field) }
      let(:details) { [FactoryBot.create(:chargeback_rate_detail, :detail_currency => currency, :chargeable_field => field)] }
      it { is_expected.to eq(symbol) }
    end
  end
end

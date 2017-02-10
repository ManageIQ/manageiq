describe ChargebackRate do
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
      cbr = FactoryGirl.create(:chargeback_rate)
      expect(cbr).to_not be_assigned
    end

    it "when assigned" do
      cbr = FactoryGirl.create(:chargeback_rate)
      host = FactoryGirl.create(:host)
      cbr.assign_to_objects(host)
      expect(cbr).to be_assigned
    end
  end

  context "#destroy" do
    it "when unassigned" do
      cbr = FactoryGirl.create(:chargeback_rate)

      cbr.destroy

      expect(cbr).to be_destroyed
      expect(cbr.errors.count).to be(0)
    end

    it "when assigned" do
      cbr  = FactoryGirl.create(:chargeback_rate, :description => "Unassigned Rate")
      host = FactoryGirl.create(:host)
      cbr.assign_to_objects(host)

      cbr.destroy

      expect(cbr).to_not be_destroyed

      expect(cbr.errors.count).to be(1)
      expect(cbr.errors.first).to include("rate is assigned and cannot be deleted")
    end

    it "when default" do
      cbr = FactoryGirl.create(:chargeback_rate, :description => "Default", :default => true)
      cbr.destroy
      expect(cbr).to_not be_destroyed
      expect(cbr.errors.count).to be(1)
      expect(cbr.errors.first).to include("default rate cannot be deleted")
    end

    it "when non-default" do
      cbr = FactoryGirl.create(:chargeback_rate, :description => "Non-default", :default => false)
      cbr.destroy
      expect(cbr).to be_destroyed
      expect(cbr.errors.count).to be(0)
    end
  end

  describe '#currency_symbol' do
    let(:rate) { FactoryGirl.build(:chargeback_rate, :chargeback_rate_details => details) }
    subject { rate.currency_symbol }

    context 'when there are no rate details' do
      let(:details) { [] }
      it { is_expected.to be_nil }
    end

    context 'when there are valid rate details' do
      let(:symbol) { '฿' }
      let(:currency) { FactoryGirl.create(:chargeback_rate_detail_currency, :symbol => symbol) }
      let(:details) { [FactoryGirl.create(:chargeback_rate_detail, :detail_currency => currency)] }
      it { is_expected.to eq(symbol) }
    end
  end
end

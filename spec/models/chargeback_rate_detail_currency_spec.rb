describe ChargebackRateDetailCurrency do
  it "has a valid factory" do
    expect(FactoryBot.create(:chargeback_rate_detail_currency)).to be_valid
  end
  it "is invalid without a code" do
    expect(FactoryBot.build(:chargeback_rate_detail_currency, :code => nil)).not_to be_valid
  end
  it "is invalid without a name" do
    expect(FactoryBot.build(:chargeback_rate_detail_currency, :name => nil)).not_to be_valid
  end
  it "is invalid without a full_name" do
    expect(FactoryBot.build(:chargeback_rate_detail_currency, :full_name => nil)).not_to be_valid
  end
  it "is invalid without a symbol" do
    expect(FactoryBot.build(:chargeback_rate_detail_currency, :symbol => nil)).not_to be_valid
  end
end

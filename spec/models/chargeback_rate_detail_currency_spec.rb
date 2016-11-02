describe ChargebackRateDetailCurrency do
  it "has a valid factory" do
    expect(FactoryGirl.create(:chargeback_rate_detail_currency)).to be_valid
  end
  it "is invalid without a code" do
    expect(FactoryGirl.build(:chargeback_rate_detail_currency, :code => nil)).not_to be_valid
  end
  it "is invalid without a name" do
    expect(FactoryGirl.build(:chargeback_rate_detail_currency, :name => nil)).not_to be_valid
  end
  it "is invalid without a full_name" do
    expect(FactoryGirl.build(:chargeback_rate_detail_currency, :full_name => nil)).not_to be_valid
  end
  it "is invalid without a symbol" do
    expect(FactoryGirl.build(:chargeback_rate_detail_currency, :symbol => nil)).not_to be_valid
  end
  it "is invalid without a unicode_hex" do
    expect(FactoryGirl.build(:chargeback_rate_detail_currency, :unicode_hex => nil)).not_to be_valid
  end
end

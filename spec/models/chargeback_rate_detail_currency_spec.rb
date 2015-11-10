require 'spec_helper'

describe ChargebackRateDetailCurrency do
  it "has a valid factory" do
    expect(FactoryGirl.create(:chargeback_rate_detail_currency_EUR)).to be_valid
  end
  it "is invalid without a code" do
    expect(FactoryGirl.build(:chargeback_rate_detail_currency_EUR, :code => nil)).not_to be_valid
  end
  it "is invalid without a name" do
    expect(FactoryGirl.build(:chargeback_rate_detail_currency_EUR, :name => nil)).not_to be_valid
  end
  it "is invalid without a full_name" do
    expect(FactoryGirl.build(:chargeback_rate_detail_currency_EUR, :full_name => nil)).not_to be_valid
  end
  it "is invalid without a symbol" do
    expect(FactoryGirl.build(:chargeback_rate_detail_currency_EUR, :symbol => nil)).not_to be_valid
  end

  it "is invalid without a unicode_hex" do
    expect(FactoryGirl.build(:chargeback_rate_detail_currency_EUR, :unicode_hex => nil)).not_to be_valid
  end
end

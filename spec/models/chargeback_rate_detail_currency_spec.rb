require 'spec_helper'

describe ChargebackRateDetailCurrency do
  it "has a valid factory" do
    FactoryGirl.create(:chargeback_rate_detail_currency_EUR).should be_valid
  end
  it "is invalid without a code" do
    FactoryGirl.build(:chargeback_rate_detail_currency_EUR, code: nil).should_not be_valid
  end
  it "is invalid without a name" do
    FactoryGirl.build(:chargeback_rate_detail_currency_EUR, name: nil).should_not be_valid
  end
  it "is invalid without a full_name" do
    FactoryGirl.build(:chargeback_rate_detail_currency_EUR, full_name: nil).should_not be_valid
  end
  it "is invalid without a symbol" do
    FactoryGirl.build(:chargeback_rate_detail_currency_EUR, symbol: nil).should_not be_valid
  end
  it "is invalid without a unicode_hex" do
    FactoryGirl.build(:chargeback_rate_detail_currency_EUR, unicode_hex: nil).should_not be_valid
  end
  it "is invalid with a empty array unicode_hex" do
    FactoryGirl.build(:chargeback_rate_detail_currency_EUR, unicode_hex: []).should_not be_valid
  end
end

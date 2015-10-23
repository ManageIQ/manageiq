require 'spec_helper'

describe ChargebackRateDetailMeasure do
  it "has a valid factory" do
    FactoryGirl.create(:chargeback_rate_detail_measure_bytes).should be_valid
  end

  it "is invalid without a name" do
    FactoryGirl.build(:chargeback_rate_detail_measure_bytes, :name => nil).should_not be_valid
  end

  it "is invalid without a step" do
    FactoryGirl.build(:chargeback_rate_detail_measure_bytes, :step => nil).should_not be_valid
  end

  it "is invalid with a step less than 0" do
    FactoryGirl.build(:chargeback_rate_detail_measure_bytes, :step => -9).should_not be_valid
  end

  it "is invalid with a empty array units" do
    FactoryGirl.build(:chargeback_rate_detail_measure_bytes, :units => []).should_not be_valid
  end

  it "is invalid with a only one array units" do
    FactoryGirl.build(:chargeback_rate_detail_measure_bytes, :units => ["KB"]).should_not be_valid
  end

  it "is invalid with a units_display lenght diferent that the units lenght" do
    FactoryGirl.build(:chargeback_rate_detail_measure_bytes,
                      :units         => %w(Bs KBs GBs),
                      :units_display => %w(kbps mbps)).should_not be_valid
  end
end

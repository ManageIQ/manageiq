describe ChargebackRateDetailMeasure do
  it "has a valid factory" do
    expect(FactoryGirl.create(:chargeback_rate_detail_measure)).to be_valid
  end

  it "is invalid without a name" do
    expect(FactoryGirl.build(:chargeback_rate_detail_measure, :name => nil)).not_to be_valid
  end

  it "is invalid without a step" do
    expect(FactoryGirl.build(:chargeback_rate_detail_measure, :step => nil)).not_to be_valid
  end

  it "is invalid with a step less than 0" do
    expect(FactoryGirl.build(:chargeback_rate_detail_measure, :step => -9)).not_to be_valid
  end

  it "is invalid with a empty array units" do
    expect(FactoryGirl.build(:chargeback_rate_detail_measure, :units => [])).not_to be_valid
  end

  it "is invalid with a only one array units" do
    expect(FactoryGirl.build(:chargeback_rate_detail_measure, :units => ["KB"])).not_to be_valid
  end

  it "is invalid with a units_display lenght diferent that the units lenght" do
    expect(FactoryGirl.build(:chargeback_rate_detail_measure,
                      :units         => %w(Bs KBs GBs),
                      :units_display => %w(kbps mbps))).not_to be_valid
  end
end

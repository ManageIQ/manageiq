require "spec_helper"

describe ChargebackRateDetail do
  it "#cost" do
    cvalue   = 42.0
    rate     = 8.26
    per_time = 'monthly'
    per_unit = 'megabytes'
    cbd = FactoryGirl.create(:chargeback_rate_detail, :rate => rate, :per_time => per_time, :per_unit => per_unit, :enabled => true)
    cbd.cost(cvalue).should == cvalue * cbd.hourly_rate

    cbd.group   = 'fixed'
    cbd.cost(cvalue).should == cbd.hourly_rate

    cbd.enabled = false
    cbd.cost(cvalue).should == 0.0
  end

  it "#tiered" do
    cvalue = 3.0
    rate = 0.15
    per_time = 'daily'
    per_unit = 'megabytes'

    tier = FactoryGirl.create(:chargeback_tier, :rate_below => 0.0, :rate_above => 0.5)
    tier_id=tier.id
    tier_detail1 = FactoryGirl.create(:chargeback_tier_detail, :chargeback_tier_id => tier_id, :start => 1.0, :end => 2.0, :tier_rate => 0.1  )
    tier_detail2 = FactoryGirl.create(:chargeback_tier_detail, :chargeback_tier_id => tier_id, :start => 2.0, :end => 4.0, :tier_rate => 0.15)
    tier_detail3 = FactoryGirl.create(:chargeback_tier_detail, :chargeback_tier_id => tier_id, :start => 4.0, :end => 8.0, :tier_rate => 0.2)

    cbd = FactoryGirl.create(:chargeback_rate_detail, :chargeback_tier_id => tier_id, :per_time => per_time, :per_unit => per_unit, :enabled => true)
    cbd.cost(cvalue).should == cvalue * cbd.hourly_rate

    cbd.group = 'fixed'
    cbd.cost(cvalue).should == 0.0

    cbd.enabled = false
    cbd.cost(cvalue).should == 0.0
  end




  it "#hourly_rate" do
    [
      '0',
      '0.0',
      '0.00'
    ].each do |rate|
      cbd = FactoryGirl.create(:chargeback_rate_detail, :rate => rate)
      cbd.hourly_rate.should == 0.0
    end

    rate = 8.26
    [
      'hourly',   'megabytes',  rate,
      'daily',    'megabytes',  rate / 24,
      'weekly',   'megabytes',  rate / 24 / 7,
      'monthly',  'megabytes',  rate / 24 / 30,
      'yearly',   'megabytes',  rate / 24 / 365,
      'yearly',   'gigabytes',  rate / 24 / 365 / 1.gigabyte,
    ].each_slice(3) do |per_time, per_unit, hourly_rate|
      cbd = FactoryGirl.create(:chargeback_rate_detail, :rate => rate, :per_time => per_time, :per_unit => per_unit)
      cbd.hourly_rate.should == hourly_rate
    end

    cbd = FactoryGirl.create(:chargeback_rate_detail, :rate => rate, :per_time => 'annually')
    -> { cbd.hourly_rate }.should raise_error(RuntimeError, "rate time unit of 'annually' not supported")
  end

  it "#rate_adjustment" do
    value = 10.gigabytes

    [
      'megabytes', value,
      'gigabytes', value / 1.gigabyte,
    ].each_slice(2) do |per_unit, rate_adjustment|
      cbd = FactoryGirl.create(:chargeback_rate_detail, :per_unit => per_unit)
      cbd.rate_adjustment(value).should == rate_adjustment
    end
  end

  it "#rate_name" do
    source = 'used'
    group  = 'cpu'
    cbd = FactoryGirl.create(:chargeback_rate_detail, :source => source, :group => group)
    cbd.rate_name.should == "#{group}_#{source}"
  end

  it "#friendly_rate" do
    friendly_rate = "My Rate"
    cbd = FactoryGirl.create(:chargeback_rate_detail, :friendly_rate => friendly_rate)
    cbd.friendly_rate.should == friendly_rate

    cbd = FactoryGirl.create(:chargeback_rate_detail, :group => 'fixed', :per_time => 'monthly', :rate => '2.53')
    cbd.friendly_rate.should == "2.53 Monthly"

    cbd = FactoryGirl.create(:chargeback_rate_detail, :per_unit => 'gigabytes', :per_time => 'monthly', :rate => '2.53')
    cbd.friendly_rate.should == "Monthly @ 2.53 per GB"
  end

  it "#per_unit_display" do
    [
      'megahertz', 'MHz',
      'megabytes', 'MB',
      'gigabytes', 'GB',
      'kbps',      'KBps',
      'ohms',      'Ohms'
    ].each_slice(2) do |per_unit, per_unit_display|
      cbd = FactoryGirl.create(:chargeback_rate_detail, :per_unit => per_unit)
      cbd.per_unit_display.should == per_unit_display
    end
  end

  it "#rate_type" do
    cbd = FactoryGirl.create(:chargeback_rate_detail)
    cbd.rate_type.should be_nil

    rate_type = 'ad-hoc'
    cb = FactoryGirl.create(:chargeback_rate, :rate_type => rate_type)
    cbd.chargeback_rate = cb
    cbd.rate_type.should == rate_type
  end
end

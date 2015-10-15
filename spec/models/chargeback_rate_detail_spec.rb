require "spec_helper"

describe ChargebackRateDetail do

  it "#cost" do
    cvalue   = 42.0
    rate     = 8.26
    per_time = 'monthly'
    per_unit = 'megabytes'
    cbd = FactoryGirl.create(:chargeback_rate_detail, :rate => rate, :per_time => per_time, :per_unit => per_unit, :enabled => true)
    cbd.cost(cvalue).should == cvalue * cbd.hourly_rate

    cbd.group = 'fixed'
    cbd.cost(cvalue).should == cbd.hourly_rate

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
    cbdm = FactoryGirl.create(:chargeback_rate_detail_measure_bytes)
    rate = 8.26
    [
      'hourly',   'megabytes',  rate,
      'daily',    'megabytes',  rate / 24,
      'weekly',   'megabytes',  rate / 24 / 7,
      'monthly',  'megabytes',  rate / 24 / 30,
      'yearly',   'megabytes',  rate / 24 / 365,
      'yearly',   'gigabytes',  rate / 24 / 365 / 1024,
    ].each_slice(3) do |per_time, per_unit, hourly_rate|
      cbd = FactoryGirl.create(:chargeback_rate_detail, :rate => rate, :per_time => per_time, :per_unit => per_unit,:metric => 'derived_memory_available', :chargeback_rate_detail_measure_id => cbdm.id)
      cbd.hourly_rate.should == hourly_rate
    end

    cbd = FactoryGirl.create(:chargeback_rate_detail, :rate => rate, :per_time => 'annually')
    lambda { cbd.hourly_rate }.should raise_error(RuntimeError, "rate time unit of 'annually' not supported")
  end

  it "#rate_adjustment" do
    value = 10.gigabytes
    cbdm = FactoryGirl.create(:chargeback_rate_detail_measure_bytes)
    [
      'megabytes', value,
      'gigabytes', value / 1024,
    ].each_slice(2) do |per_unit, rate_adjustment|
      cbd = FactoryGirl.create(:chargeback_rate_detail, :per_unit => per_unit, :metric => 'derived_memory_available', :chargeback_rate_detail_measure_id => cbdm.id)
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

    cbd = FactoryGirl.create(:chargeback_rate_detail, :per_unit => 'cpu', :per_time => 'monthly', :rate => '2.53')
    cbd.friendly_rate.should == "Monthly @ 2.53 per Cpu"
  end

  it "#per_unit_display_without_measurements" do
    [
      'cpu',       'Cpu',
      'ohms',      'Ohms'
    ].each_slice(2) do |per_unit, per_unit_display|
      cbd = FactoryGirl.create(:chargeback_rate_detail, :per_unit => per_unit)
      cbd.per_unit_display.should == per_unit_display
    end
  end

  it "#per_unit_display_with_measurements" do
    cbdm = FactoryGirl.create(:chargeback_rate_detail_measure_bytes)
    cbd  = FactoryGirl.create(:chargeback_rate_detail, :per_unit => 'megabytes', :chargeback_rate_detail_measure_id => cbdm.id)
    cbd.per_unit_display.should == 'MB'
  end

  it "#rate_type" do
    cbd = FactoryGirl.create(:chargeback_rate_detail)
    cbd.rate_type.should be_nil

    rate_type = 'ad-hoc'
    cb = FactoryGirl.create(:chargeback_rate, :rate_type => rate_type)
    cbd.chargeback_rate = cb
    cbd.rate_type.should == rate_type
  end

  it "diferents_per_units_rates_should_have_the_same_cost" do
    cbdm = FactoryGirl.create(:chargeback_rate_detail_measure_bytes)
    # should be the same cost. bytes to megabytes and gigabytes to megabytes
    cbd_bytes = FactoryGirl.create(:chargeback_rate_detail, :per_unit => 'bytes',
     :metric => 'derived_memory_available', :per_time => 'monthly',
      :chargeback_rate_detail_measure_id => cbdm.id)
    cbd_gigabytes = FactoryGirl.create(:chargeback_rate_detail, :per_unit => 'gigabytes',
     :metric => 'derived_memory_available', :per_time => 'monthly',
      :chargeback_rate_detail_measure_id => cbdm.id)
    cbd_bytes.cost(100).should == cbd_gigabytes.cost(100)
  end
end

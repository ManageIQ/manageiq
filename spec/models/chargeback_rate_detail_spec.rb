describe ChargebackRateDetail do
  it "#cost" do
    cvalue   = 42.0
    rate     = 8.26
    per_time = 'monthly'
    per_unit = 'megabytes'
    cbd = FactoryGirl.create(:chargeback_rate_detail,
                             :rate     => rate,
                             :per_time => per_time,
                             :per_unit => per_unit,
                             :enabled  => true
                            )
    expect(cbd.cost(cvalue)).to eq(cvalue * cbd.hourly_rate)

    cbd.group = 'fixed'
    expect(cbd.cost(cvalue)).to eq(cbd.hourly_rate)

    cbd.enabled = false
    expect(cbd.cost(cvalue)).to eq(0.0)
  end

  it "#hourly_rate" do
    [
      '0',
      '0.0',
      '0.00'
    ].each do |rate|
      cbd = FactoryGirl.create(:chargeback_rate_detail, :rate => rate)
      expect(cbd.hourly_rate).to eq(0.0)
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
      cbd = FactoryGirl.create(:chargeback_rate_detail,
                               :rate                              => rate,
                               :per_time                          => per_time,
                               :per_unit                          => per_unit,
                               :metric                            => 'derived_memory_available',
                               :chargeback_rate_detail_measure_id => cbdm.id
                              )
      expect(cbd.hourly_rate).to eq(hourly_rate)
    end

    cbd = FactoryGirl.create(:chargeback_rate_detail, :rate => rate, :per_time => 'annually')
    expect  { cbd.hourly_rate }.to raise_error(RuntimeError, "rate time unit of 'annually' not supported")
  end

  it "#rate_adjustment" do
    value = 10.gigabytes
    cbdm = FactoryGirl.create(:chargeback_rate_detail_measure_bytes)
    [
      'megabytes', value,
      'gigabytes', value / 1024,
    ].each_slice(2) do |per_unit, rate_adjustment|
      cbd = FactoryGirl.create(:chargeback_rate_detail, :per_unit => per_unit, :metric => 'derived_memory_available',
       :chargeback_rate_detail_measure_id => cbdm.id)
      expect(cbd.rate_adjustment(value)).to eq(rate_adjustment)
    end
  end

  it "#rate_name" do
    source = 'used'
    group  = 'cpu'
    cbd = FactoryGirl.create(:chargeback_rate_detail, :source => source, :group => group)
    expect(cbd.rate_name).to eq("#{group}_#{source}")
  end

  it "#friendly_rate" do
    friendly_rate = "My Rate"
    cbd = FactoryGirl.create(:chargeback_rate_detail, :friendly_rate => friendly_rate)
    expect(cbd.friendly_rate).to eq(friendly_rate)

    cbd = FactoryGirl.create(:chargeback_rate_detail, :group => 'fixed', :per_time => 'monthly', :rate => '2.53')
    expect(cbd.friendly_rate).to eq("2.53 Monthly")

    cbd = FactoryGirl.create(:chargeback_rate_detail, :per_unit => 'cpu', :per_time => 'monthly', :rate => '2.53')
    expect(cbd.friendly_rate).to eq("Monthly @ 2.53 per Cpu")
  end

  it "#per_unit_display_without_measurements" do
    [
      'cpu',       'Cpu',
      'ohms',      'Ohms'
    ].each_slice(2) do |per_unit, per_unit_display|
      cbd = FactoryGirl.create(:chargeback_rate_detail, :per_unit => per_unit)
      expect(cbd.per_unit_display).to eq(per_unit_display)
    end
  end

  it "#per_unit_display_with_measurements" do
    cbdm = FactoryGirl.create(:chargeback_rate_detail_measure_bytes)
    cbd  = FactoryGirl.create(:chargeback_rate_detail,
                              :per_unit                          => 'megabytes',
                              :chargeback_rate_detail_measure_id => cbdm.id
                             )
    expect(cbd.per_unit_display).to eq('MB')
  end

  it "#rate_type" do
    cbd = FactoryGirl.create(:chargeback_rate_detail)
    expect(cbd.rate_type).to be_nil

    rate_type = 'ad-hoc'
    cb = FactoryGirl.create(:chargeback_rate, :rate_type => rate_type)
    cbd.chargeback_rate = cb
    expect(cbd.rate_type).to eq(rate_type)
  end

  it "is valid without per_unit, metric and measure" do
    %w(
      'cpu' 'derived_vm_numvcpus' nil,
      nil   nil                   nil)
      .each_slice(3) do |per_unit, metric, chargeback_rate_detail_measure_id|
        cbd = FactoryGirl.create(:chargeback_rate_detail,
                                 :per_unit                          => per_unit,
                                 :metric                            => metric,
                                 :chargeback_rate_detail_measure_id => chargeback_rate_detail_measure_id
                                )
        expect(cbd).to be_valid
      end
  end

  it "diferents_per_units_rates_should_have_the_same_cost" do
    cbdm = FactoryGirl.create(:chargeback_rate_detail_measure_bytes)
    # should be the same cost. bytes to megabytes and gigabytes to megabytes
    cbd_bytes = FactoryGirl.create(:chargeback_rate_detail,
                                   :per_unit                          => 'bytes',
                                   :metric                            => 'derived_memory_available',
                                   :per_time                          => 'monthly',
                                   :chargeback_rate_detail_measure_id => cbdm.id
                                  )
    cbd_gigabytes = FactoryGirl.create(:chargeback_rate_detail,
                                       :per_unit                          => 'gigabytes',
                                       :metric                            => 'derived_memory_available',
                                       :per_time                          => 'monthly',
                                       :chargeback_rate_detail_measure_id => cbdm.id
                                      )
    expect(cbd_bytes.cost(100)).to eq(cbd_gigabytes.cost(100))
  end

  it "#show_rates" do
    cbm = FactoryGirl.create(:chargeback_rate_detail_measure_bytes)
    cbc = FactoryGirl.create(:chargeback_rate_detail_currency_EUR)

    cbd = FactoryGirl.create(:chargeback_rate_detail_cpu_allocated,
                             :rate                               => '0.0',
                             :chargeback_rate_detail_currency_id => cbc.id
                             )
    expect(cbd.show_rates(cbc.code)).to eq("EUR")

    cbd = FactoryGirl.create(:chargeback_rate_detail_fixed_compute_cost,
                             :rate                               => '1.47',
                             :chargeback_rate_detail_measure_id  => cbm.id,
                             :chargeback_rate_detail_currency_id => cbc.id
                             )
    expect(cbd.show_rates(cbc.code)).to eq("EUR / Day")

    cbd = FactoryGirl.create(:chargeback_rate_detail_memory_allocated,
                             :rate                               => '1.47',
                             :chargeback_rate_detail_measure_id  => cbm.id,
                             :chargeback_rate_detail_currency_id => cbc.id
                             )
    expect(cbd.show_rates(cbc.code)).to eq("EUR / Day / MB")
  end
end

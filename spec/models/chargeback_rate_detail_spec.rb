describe ChargebackRateDetail do
  let(:field) { FactoryGirl.build(:chargeable_field) }
  describe "#chargeback_rate" do
    it "is invalid without a valid chargeback_rate" do
      invalid_chargeback_rate_id = (ChargebackRate.maximum(:id) || -1) + 1
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail,
                                                 :chargeable_field   => field,
                                                 :chargeback_rate_id => invalid_chargeback_rate_id)
      expect(chargeback_rate_detail).to be_invalid
      expect(chargeback_rate_detail.errors.messages).to include(:chargeback_rate => [/can't be blank/])
    end
  end

  describe "#find_rate" do
    let(:cvalue) { {"val1" => 0.0, "val2" => 10.0, "val3" => 20.0, "val4" => 50.0} }
    let(:cbt1) { FactoryGirl.build(:chargeback_tier, :start => 0, :finish => 10, :fixed_rate => 3.0, :variable_rate => 0.3) }
    let(:cbt2) { FactoryGirl.build(:chargeback_tier, :start => 10, :finish => 50, :fixed_rate => 2.0, :variable_rate => 0.2) }
    let(:cbt3) { FactoryGirl.build(:chargeback_tier, :start => 50, :finish => Float::INFINITY, :fixed_rate => 1.0, :variable_rate => 0.1) }
    let(:cbd) do
      FactoryGirl.build(:chargeback_rate_detail, :chargeback_tiers => [cbt3, cbt2, cbt1],
                                                 :chargeable_field => field)
    end

    it "finds proper rate according the value" do
      expect(cbd.find_rate(cvalue["val1"])).to eq([cbt1.fixed_rate, cbt1.variable_rate])
      expect(cbd.find_rate(cvalue["val2"])).to eq([cbt1.fixed_rate, cbt1.variable_rate])
      expect(cbd.find_rate(cvalue["val3"])).to eq([cbt2.fixed_rate, cbt2.variable_rate])
      expect(cbd.find_rate(cvalue["val4"])).to eq([cbt2.fixed_rate, cbt2.variable_rate])
    end

    context 'with rate adjustment' do
      let(:measure) do
        FactoryGirl.build(:chargeback_rate_detail_measure,
                          :units_display => %w(B KB MB GB TB),
                          :units         => %w(bytes kilobytes megabytes gigabytes terabytes))
      end
      let(:field) { FactoryGirl.create(:chargeable_field_storage_allocated, :detail_measure => measure) }
      let(:cbd) do
        # This charges per gigabyte, tiers are per gigabytes
        FactoryGirl.build(:chargeback_rate_detail,
                          :chargeback_tiers => [cbt1, cbt2, cbt3],
                          :chargeable_field => field,
                          :per_unit         => 'gigabytes')
      end
      it 'finds proper tier for the value' do
        expect(cbd.find_rate(0.0)).to                   eq([cbt1.fixed_rate, cbt1.variable_rate])
        expect(cbd.find_rate(10.gigabytes)).to          eq([cbt1.fixed_rate, cbt1.variable_rate])
        expect(cbd.find_rate(10.gigabytes + 1.byte)).to eq([cbt2.fixed_rate, cbt2.variable_rate])
        expect(cbd.find_rate(50.gigabytes)).to          eq([cbt2.fixed_rate, cbt2.variable_rate])
        expect(cbd.find_rate(50.gigabytes + 1.byte)).to eq([cbt3.fixed_rate, cbt3.variable_rate])
      end
    end
  end

  let(:consumption) { instance_double('Consumption', :hours_in_month => (1.month / 1.hour)) }

  it '#hourly_cost' do
    cvalue   = 42.0
    fixed_rate = 5.0
    variable_rate = 8.26
    tier_start = 0
    tier_finish = Float::INFINITY
    per_time = 'monthly'
    per_unit = 'megabytes'
    cbd = FactoryGirl.build(:chargeback_rate_detail,
                            :chargeable_field => field,
                            :per_time => per_time,
                            :per_unit => per_unit,
                            :enabled  => true)
    cbt = FactoryGirl.create(:chargeback_tier,
                             :chargeback_rate_detail_id => cbd.id,
                             :start                     => tier_start,
                             :finish                    => tier_finish,
                             :fixed_rate                => fixed_rate,
                             :variable_rate             => variable_rate)
    cbd.update(:chargeback_tiers => [cbt])
    expect(cbd.hourly_cost(cvalue, consumption)).to eq(cvalue * cbd.hourly(variable_rate, consumption) + cbd.hourly(fixed_rate, consumption))

    cbd.chargeable_field = FactoryGirl.build(:chargeable_field_fixed_compute_1)
    expect(cbd.hourly_cost(1, consumption)).to eq(cbd.hourly(variable_rate, consumption) + cbd.hourly(fixed_rate, consumption))

    cbd.enabled = false
    expect(cbd.hourly_cost(cvalue, consumption)).to eq(0.0)
  end

  describe '#hourly (rate)' do
    let(:rate) { 8.26 }
    it 'returns 0 when the rate was 0' do
      [
        0,
        0.0,
        0.00
      ].each do |zero|
        cbd = FactoryGirl.build(:chargeback_rate_detail, :per_time => 'hourly')
        expect(cbd.hourly(zero, consumption)).to eq(0.0)
      end
    end

    it 'calculates hourly rate for given rate' do
      cbdm = FactoryGirl.create(:chargeback_rate_detail_measure)
      [
        'hourly',   'megabytes',  rate,
        'daily',    'megabytes',  rate / 24,
        'weekly',   'megabytes',  rate / 24 / 7,
        'monthly',  'megabytes',  rate / 24 / 30,
        'yearly',   'megabytes',  rate / 24 / 365
      ].each_slice(3) do |per_time, per_unit, hourly_rate|
        cbd = FactoryGirl.build(:chargeback_rate_detail,
                                :per_time                          => per_time,
                                :per_unit                          => per_unit,
                                :metric                            => 'derived_memory_available',
                                :chargeback_rate_detail_measure_id => cbdm.id)
        expect(cbd.hourly(rate, consumption)).to eq(hourly_rate)
      end
    end

    let(:annual_rate) { FactoryGirl.build(:chargeback_rate_detail, :per_time => 'annually') }
    it 'cannot calculate for unknown time interval' do
      expect { annual_rate.hourly(rate, consumption) }.to raise_error(RuntimeError,
                                                                      "rate time unit of 'annually' not supported")
    end

    let(:monthly_rate) { FactoryGirl.build(:chargeback_rate_detail, :per_time => 'monthly') }
    let(:weekly_consumption) { Chargeback::ConsumptionWithRollups.new([], Time.current - 1.week, Time.current) }
    it 'monhtly rate returns correct hourly(_rate) when consumption slice is weekly' do
      expect(monthly_rate.hourly(rate, weekly_consumption)).to eq(rate / (1.month / 1.hour))
    end
  end

  it "#rate_adjustment" do
    value = 10.gigabytes
    field = FactoryGirl.build(:chargeable_field_memory_allocated) # the core metric is in megabytes
    [
      'megabytes', value,
      'gigabytes', value / 1024,
    ].each_slice(2) do |per_unit, rate_adjustment|
      cbd = FactoryGirl.build(:chargeback_rate_detail, :per_unit => per_unit, :metric => 'derived_memory_available',
                                                       :chargeable_field => field)
      expect(cbd.rate_adjustment * value).to eq(rate_adjustment)
    end
  end

  it "#friendly_rate" do
    friendly_rate = "My Rate"
    cbd = FactoryGirl.build(:chargeback_rate_detail, :friendly_rate => friendly_rate)
    expect(cbd.friendly_rate).to eq(friendly_rate)

    cbd = FactoryGirl.build(:chargeback_rate_detail,
                            :per_time         => 'monthly',
                            :chargeable_field => FactoryGirl.build(:chargeable_field_fixed_compute_1))
    cbt = FactoryGirl.create(:chargeback_tier, :start => 0, :chargeback_rate_detail_id => cbd.id,
                       :finish => Float::INFINITY, :fixed_rate => 1.0, :variable_rate => 2.0)
    cbd.update(:chargeback_tiers => [cbt])
    expect(cbd.friendly_rate).to eq("3.0 Monthly")

    cbd = FactoryGirl.build(:chargeback_rate_detail, :per_unit => 'cpu', :per_time => 'monthly', :detail_measure => nil,
                            :chargeable_field => field)
    cbt = FactoryGirl.create(:chargeback_tier, :start => 0, :chargeback_rate_detail_id => cbd.id,
                             :finish => Float::INFINITY, :fixed_rate => 1.0, :variable_rate => 2.0)
    cbd.update(:chargeback_tiers => [cbt])
    expect(cbd.friendly_rate).to eq("Monthly @ 1.0 + 2.0 per Cpu from 0.0 to Infinity")

    cbd = FactoryGirl.build(:chargeback_rate_detail, :per_unit => 'megabytes', :per_time => 'monthly',
                            :detail_measure => nil, :chargeable_field => field)
    cbt1 = FactoryGirl.create(:chargeback_tier, :start => 0.0, :chargeback_rate_detail_id => cbd.id,
                             :finish => 5.0, :fixed_rate => 1.0, :variable_rate => 2.0)
    cbt2 = FactoryGirl.create(:chargeback_tier, :start => 5.0, :chargeback_rate_detail_id => cbd.id,
                             :finish => Float::INFINITY, :fixed_rate => 5.0, :variable_rate => 2.5)
    cbd.update(:chargeback_tiers => [cbt1, cbt2])
    expect(cbd.friendly_rate).to eq("Monthly @ 1.0 + 2.0 per Megabytes from 0.0 to 5.0\n\
Monthly @ 5.0 + 2.5 per Megabytes from 5.0 to Infinity")
  end

  it "#per_unit_display_without_measurements" do
    [
      'cpu',       'Cpu',
      'ohms',      'Ohms'
    ].each_slice(2) do |per_unit, per_unit_display|
      cbd = FactoryGirl.build(:chargeback_rate_detail, :per_unit => per_unit, :detail_measure => nil)
      expect(cbd.per_unit_display).to eq(per_unit_display)
    end
  end

  it "#per_unit_display_with_measurements" do
    cbdm = FactoryGirl.create(:chargeback_rate_detail_measure,
                              :units_display => %w(B KB MB GB TB),
                              :units         => %w(bytes kilobytes megabytes gigabytes terabytes))

    cbd  = FactoryGirl.build(:chargeback_rate_detail,
                             :per_unit                          => 'megabytes',
                             :chargeback_rate_detail_measure_id => cbdm.id)
    expect(cbd.per_unit_display).to eq('MB')
  end

  it "#rate_type" do
    rate_type = 'ad-hoc'
    cb = FactoryGirl.create(:chargeback_rate, :rate_type => rate_type)
    cbd = FactoryGirl.build(:chargeback_rate_detail, :chargeback_rate => cb)
    expect(cbd.rate_type).to eq(rate_type)
  end

  it "is valid without per_unit, metric and measure" do
    %w(
      'cpu' 'derived_vm_numvcpus' nil,
      nil   nil                   nil)
      .each_slice(3) do |per_unit, metric, chargeback_rate_detail_measure_id|
        cbd = FactoryGirl.build(:chargeback_rate_detail,
                                :chargeable_field                  => field,
                                :per_unit                          => per_unit,
                                :metric                            => metric,
                                :chargeback_rate_detail_measure_id => chargeback_rate_detail_measure_id)
        cbt = FactoryGirl.create(:chargeback_tier,
                                 :chargeback_rate_detail_id => cbd.id,
                                 :start                     => 0,
                                 :finish                    => Float::INFINITY,
                                 :fixed_rate                => 0.0,
                                 :variable_rate             => 0.0)
        cbd.update(:chargeback_tiers => [cbt])
        expect(cbd).to be_valid
      end
  end

  it "diferents_per_units_rates_should_have_the_same_cost" do
    cbdm = FactoryGirl.create(:chargeback_rate_detail_measure,
                              :units_display => %w(B KB MB GB TB),
                              :units         => %w(bytes kilobytes megabytes gigabytes terabytes))

    # should be the same cost. bytes to megabytes and gigabytes to megabytes
    cbd_bytes = FactoryGirl.build(:chargeback_rate_detail,
                                  :chargeable_field                  => field,
                                  :per_unit                          => 'bytes',
                                  :metric                            => 'derived_memory_available',
                                  :per_time                          => 'monthly',
                                  :chargeback_rate_detail_measure_id => cbdm.id)
    cbd_gigabytes = FactoryGirl.build(:chargeback_rate_detail,
                                      :chargeable_field                  => field,
                                      :per_unit                          => 'gigabytes',
                                      :metric                            => 'derived_memory_available',
                                      :per_time                          => 'monthly',
                                      :chargeback_rate_detail_measure_id => cbdm.id)
    expect(cbd_bytes.hourly_cost(100, consumption)).to eq(cbd_gigabytes.hourly_cost(100, consumption))
  end

  it "#show_rates" do
    cbm = FactoryGirl.create(:chargeback_rate_detail_measure,
                             :units_display => %w(B KB MB GB TB),
                             :units         => %w(bytes kilobytes megabytes gigabytes terabytes))

    cbc = FactoryGirl.create(:chargeback_rate_detail_currency, :code => "EUR")

    cbd = FactoryGirl.build(:chargeback_rate_detail_fixed_compute_cost,
                            :chargeback_rate_detail_measure_id  => cbm.id,
                            :chargeback_rate_detail_currency_id => cbc.id
                           )
    expect(cbd.show_rates).to eq("EUR / Day")

    cbd = FactoryGirl.build(:chargeback_rate_detail_memory_allocated,
                            :chargeback_rate_detail_measure_id  => cbm.id,
                            :chargeback_rate_detail_currency_id => cbc.id
                           )
    expect(cbd.show_rates).to eq("EUR / Day / MB")
  end

  context "tier set correctness" do
    it "add an initial invalid tier" do
      cbt1 = FactoryGirl.build(:chargeback_tier, :start => 0, :finish => 5)
      cbd  = FactoryGirl.build(:chargeback_rate_detail, :chargeback_tiers => [cbt1])

      expect(cbd.contiguous_tiers?).to be false
    end

    it "add an initial valid tier" do
      cbt1 = FactoryGirl.build(:chargeback_tier, :start => 0, :finish => Float::INFINITY)
      cbd  = FactoryGirl.build(:chargeback_rate_detail, :chargeback_tiers => [cbt1], :chargeable_field => field)

      expect(cbd.contiguous_tiers?).to be true
    end

    it "add an invalid tier to an existing tier set" do
      cbt1 = FactoryGirl.create(:chargeback_tier, :start => 0, :finish => Float::INFINITY)
      cbd  = FactoryGirl.create(:chargeback_rate_detail, :chargeback_tiers => [cbt1], :chargeable_field => field)

      cbt2 = FactoryGirl.build(:chargeback_tier, :start => 6, :finish => Float::INFINITY)
      cbt1.finish = 5
      cbd.chargeback_tiers << cbt2

      expect(cbd.contiguous_tiers?).to be false
    end

    it "add a valid tier to an existing tier set" do
      cbt1 = FactoryGirl.create(:chargeback_tier, :start => 0, :finish => Float::INFINITY)
      cbd  = FactoryGirl.create(:chargeback_rate_detail, :chargeback_tiers => [cbt1], :chargeable_field => field)

      cbt2 = FactoryGirl.build(:chargeback_tier, :start => 5, :finish => Float::INFINITY)
      cbt1.finish = 5
      cbd.chargeback_tiers << cbt2

      expect(cbd.contiguous_tiers?).to be true
    end

    it "remove a tier from an existing tier set, leaving the set invalid" do
      cbt1 = FactoryGirl.create(:chargeback_tier, :start => 0, :finish => 5)
      cbt2 = FactoryGirl.create(:chargeback_tier, :start => 5, :finish => Float::INFINITY)
      cbd  = FactoryGirl.create(:chargeback_rate_detail, :chargeback_tiers => [cbt1, cbt2], :chargeable_field => field)

      cbd.chargeback_tiers = [cbt1]

      expect(cbd.contiguous_tiers?).to be false
    end

    it "remove a tier from an existing set of tiers" do
      cbt1 = FactoryGirl.create(:chargeback_tier, :start => 0, :finish => 5)
      cbt2 = FactoryGirl.create(:chargeback_tier, :start => 5, :finish => Float::INFINITY)
      cbd  = FactoryGirl.create(:chargeback_rate_detail, :chargeback_tiers => [cbt1, cbt2], :chargeable_field => field)

      cbt1.finish = Float::INFINITY
      cbd.chargeback_tiers = [cbt1]

      expect(cbd.contiguous_tiers?).to be true
    end

    it "remove last tier" do
      cbt1 = FactoryGirl.create(:chargeback_tier, :start => 0, :finish => Float::INFINITY)
      cbd  = FactoryGirl.create(:chargeback_rate_detail, :chargeback_tiers => [cbt1], :chargeable_field => field)
      cbd.chargeback_tiers = []

      expect(cbd.contiguous_tiers?).to be true
    end

    it "tiers should contain no gaps" do
      cbt1 = FactoryGirl.build(:chargeback_tier, :start => 0, :finish => 5)
      cbt2 = FactoryGirl.build(:chargeback_tier, :start => 6, :finish => Float::INFINITY)
      cbd  = FactoryGirl.build(:chargeback_rate_detail, :chargeback_tiers => [cbt2, cbt1])

      expect(cbd.contiguous_tiers?).to be false
    end

    it "must contain one start" do
      cbt1 = FactoryGirl.build(:chargeback_tier, :start => 0, :finish => 1)
      cbt2 = FactoryGirl.build(:chargeback_tier, :start => 0, :finish => Float::INFINITY)
      cbd  = FactoryGirl.build(:chargeback_rate_detail, :chargeback_tiers => [cbt2, cbt1])

      expect(cbd).not_to be_valid
    end

    it "must start at 0" do
      cbt1 = FactoryGirl.build(:chargeback_tier, :start => 1, :finish => 10)
      cbt2 = FactoryGirl.build(:chargeback_tier, :start => 10, :finish => Float::INFINITY)
      cbd  = FactoryGirl.build(:chargeback_rate_detail, :chargeback_tiers => [cbt2, cbt1])

      expect(cbd).not_to be_valid
    end

    it "must end at infinity" do
      cbt1 = FactoryGirl.build(:chargeback_tier, :start => 0, :finish => 1)
      cbt2 = FactoryGirl.build(:chargeback_tier, :start => 1, :finish => 1000)
      cbd  = FactoryGirl.build(:chargeback_rate_detail, :chargeback_tiers => [cbt2, cbt1])

      expect(cbd).not_to be_valid
      expect(cbd.errors[:chargeback_tiers]).to be_present
    end

    it "middle tier must not start infinity" do
      cbt1 = FactoryGirl.build(:chargeback_tier, :start => 0, :finish => Float::INFINITY)
      cbt2 = FactoryGirl.build(:chargeback_tier, :start => Float::INFINITY, :finish => Float::INFINITY)
      cbd  = FactoryGirl.build(:chargeback_rate_detail, :chargeback_tiers => [cbt2, cbt1])

      expect(cbd).not_to be_valid
    end
  end
end

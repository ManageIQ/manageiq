class ChargebackRateDetail < ApplicationRecord
  belongs_to :chargeback_rate
  belongs_to :detail_measure, :class_name => "ChargebackRateDetailMeasure", :foreign_key => :chargeback_rate_detail_measure_id
  belongs_to :detail_currency, :class_name => "ChargebackRateDetailCurrency", :foreign_key => :chargeback_rate_detail_currency_id
  has_many :chargeback_tiers, :dependent => :destroy, :autosave => true
  validates :group, :source, :presence => true
  validate :contiguous_tiers?

  FORM_ATTRIBUTES = %i(description per_time per_unit metric group source metric).freeze

  # Set the rates according to the tiers
  def find_rate(value)
    fixed_rate = 0.0
    variable_rate = 0.0
    chargeback_tiers.each do |tier|
      next if value < rate_adjustment(tier.start)
      next if value >= rate_adjustment(tier.finish)
      fixed_rate = tier.fixed_rate
      variable_rate = tier.variable_rate
      break
    end
    return fixed_rate, variable_rate
  end

  PER_TIME_MAP = {
    :hourly  => "Hour",
    :daily   => "Day",
    :weekly  => "Week",
    :monthly => "Month",
    :yearly  => "Year"
  }

  def cost(value)
    return 0.0 unless self.enabled?
    value = 1 if group == 'fixed'
    (fixed_rate, variable_rate) = find_rate(value)
    hourly(fixed_rate) + hourly(variable_rate) * value
  end

  def hourly(rate)
    case per_time
    when "hourly"  then rate
    when "daily"   then rate / 24
    when "weekly"  then rate / 24 / 7
    when "monthly" then rate / 24 / 30
    when "yearly"  then rate / 24 / 365
    else raise "rate time unit of '#{per_time}' not supported"
    end
  end

  def hourly_rate
    _fixed_rate, variable_rate = find_rate(0.0)
    return 0.0 if variable_rate.zero?

    hr = case per_time
         when "hourly"  then variable_rate
         when "daily"   then variable_rate / 24
         when "weekly"  then variable_rate / 24 / 7
         when "monthly" then variable_rate / 24 / 30
         when "yearly"  then variable_rate / 24 / 365
         else raise _("rate time unit of '%{time_type}' not supported") % {:time_type => per_time}
         end

    # Handle cases where we need to adjust per_unit to a common value.
    rate_adjustment(hr)
  end

  # Scale the rate in the unit difine by user to the default unit of the metric
  # It showing the default units of the metrics:
  # cpu_usagemhz_rate_average --> megahertz
  # derived_memory_used --> megabytes
  # derived_memory_available -->megabytes
  # net_usage_rate_average --> kbps
  # disk_usage_rate_average --> kbps
  # derived_vm_allocated_disk_storage --> bytes
  # derived_vm_used_disk_storage --> bytes

  def rate_adjustment(hr)
    case metric
    when "cpu_usagemhz_rate_average" then
      per_unit == 'megahertz' ? hr : hr = adjustment_measure(hr, 'megahertz')
    when "derived_memory_used", "derived_memory_available" then
      per_unit == 'megabytes' ? hr : hr = adjustment_measure(hr, 'megabytes')
    when "net_usage_rate_average", "disk_usage_rate_average" then
      per_unit == 'kbps' ? hr : hr = adjustment_measure(hr, 'kbps')
    when "derived_vm_allocated_disk_storage", "derived_vm_used_disk_storage" then
      per_unit == 'bytes' ? hr : hr = adjustment_measure(hr, 'bytes')
    else hr
    end
  end

  # Adjusts the hourly rate to the per unit by default
  def adjustment_measure(hr, pu_destiny)
    measure = detail_measure
    pos_pu_destiny = measure.units.index(pu_destiny)
    pos_per_unit = measure.units.index(per_unit)
    jumps = (pos_per_unit - pos_pu_destiny).abs
    if pos_per_unit > pos_pu_destiny
      hr.to_f / (measure.step**jumps)
    else
      hr * (measure.step**jumps)
    end
  end

  def rate_name
    "#{group}_#{source}"
  end

  def friendly_rate
    (fixed_rate, variable_rate) = find_rate(0.0)
    value = read_attribute(:friendly_rate)
    return value unless value.nil?

    if group == 'fixed'
      # Example: 10.00 Monthly
      "#{fixed_rate + variable_rate} #{per_time.to_s.capitalize}"
    else
      s = ""
      ChargebackTier.where(:chargeback_rate_detail_id => id).each do |tier|
        # Example: Daily @ .02 per MHz from 0.0 to Infinity
        s += "#{per_time.to_s.capitalize} @ #{tier.fixed_rate} + "\
             "#{tier.variable_rate} per #{per_unit_display} from #{tier.start} to #{tier.finish}\n"
      end
      s.chomp
    end
  end

  def per_unit_display
    detail_measure.nil? ? per_unit.to_s.capitalize : detail_measure.measures.key(per_unit)
  end

  def rate_type
    # Return parent's rate type
    chargeback_rate.rate_type unless chargeback_rate.nil?
  end

  # New method created in order to show the rates in a easier to understand way
  def show_rates(code_currency)
    hr = ChargebackRateDetail::PER_TIME_MAP[per_time.to_sym]
    rate_display = "#{detail_currency.code} / #{hr}"
    rate_display_unit = "#{rate_display} / #{per_unit_display}"
    per_unit.nil? ? rate_display : rate_display_unit
  end

  def save_tiers(tiers)
    temp = self.class.new(:chargeback_tiers => tiers)
    if temp.contiguous_tiers?
      self.chargeback_tiers.replace(tiers)
    else
      temp.errors.each {|a, e| errors.add(a, e)}
    end
  end

  # Check that tiers are complete and disjoint
  def contiguous_tiers?
    error = false

    # Note, we use sort_by vs. order since we need to call this method against
    # the in memory chargeback_tiers association and NOT hit the database.
    tiers = chargeback_tiers.sort_by(&:start)

    tiers.each_with_index do |tier, index|
      if single_tier?(tier,tiers)
        error = true if !tier.starts_with_zero? || !tier.ends_with_infinity?
      elsif first_tier?(tier,tiers)
        error = true if !tier.starts_with_zero? || tier.ends_with_infinity?
      elsif last_tier?(tier,tiers)
        error = true if !consecutive_tiers?(tier, tiers[index - 1])
        error = true if !tier.ends_with_infinity?
      elsif middle_tier?(tier,tiers)
        error = true if !consecutive_tiers?(tier, tiers[index - 1])
        error = true if tier.ends_with_infinity?
      end

      break if error
    end
    errors.add(:chargeback_tiers, _("must start at zero and not contain any gaps between start and prior end value.")) if error

    !error
  end

  def first_tier?(tier,tiers)
    tier == tiers.first
  end

  def last_tier?(tier,tiers)
    tier == tiers.last
  end

  def single_tier?(tier,tiers)
    first_tier?(tier, tiers) && last_tier?(tier, tiers)
  end

  def middle_tier?(tier,tiers)
    !first_tier?(tier, tiers) && !last_tier?(tier, tiers)
  end

  def consecutive_tiers?(tier, previous_tier)
    tier.start == previous_tier.finish
  end

  def self.default_rate_details_for(rate_type)
    rate_details = []

    fixture_file = File.join(FIXTURE_DIR, "chargeback_rates.yml")
    fixture = File.exist?(fixture_file) ? YAML.load_file(fixture_file) : []
    fixture.each do |chargeback_rate|
      next unless chargeback_rate[:rate_type] == rate_type

      chargeback_rate[:rates].each do |detail|
        detail_new = ChargebackRateDetail.new(detail.slice(*ChargebackRateDetail::FORM_ATTRIBUTES))
        detail_new.detail_measure = ChargebackRateDetailMeasure.find_by(:name => detail[:measure])
        detail_new.detail_currency = ChargebackRateDetailCurrency.find_by(:name => detail[:type_currency])
        detail_new.metric = detail[:metric]

        detail[:tiers].each do |tier|
          detail_new.chargeback_tiers << ChargebackTier.new(tier.slice(*ChargebackTier::FORM_ATTRIBUTES))
        end

        rate_details.push(detail_new)
      end
    end

    rate_details
  end
end

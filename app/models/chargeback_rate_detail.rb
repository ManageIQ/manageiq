class ChargebackRateDetail < ApplicationRecord
  belongs_to :chargeback_rate
  belongs_to :detail_measure, :class_name => "ChargebackRateDetailMeasure", :foreign_key => :chargeback_rate_detail_measure_id
  belongs_to :detail_currency, :class_name => "ChargebackRateDetailCurrency", :foreign_key => :chargeback_rate_detail_currency_id
  has_many :chargeback_tiers, :dependent => :destroy
  validates :group, :source, :presence => true
  validate :complete_tiers, :if => "!respond_to?(:rate)"

  # Set the rates according to the tiers
  def find_rate(value)
    fixed_rate = 0.0
    variable_rate = 0.0
    chargeback_tiers.each do |tier|
      next if value < rate_adjustment(tier.start)
      next if value >= rate_adjustment(tier.end)
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
    variable_rate = find_rate(0.0)
    rate = variable_rate
    return 0.0 if rate.zero?

    hr = case per_time
         when "hourly"  then rate
         when "daily"   then rate / 24
         when "weekly"  then rate / 24 / 7
         when "monthly" then rate / 24 / 30
         when "yearly"  then rate / 24 / 365
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
        s += "#{per_time.to_s.capitalize} @ #{tier.fixed_rate}"\
             "#{tier.variable_rate} per #{per_unit_display} from #{tier.start} to #{tier.end}\n"
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

  # Check that tiers are complete and disjoint
  def complete_tiers
    cbts = chargeback_tiers
    start = 0
    tier_ends = false
    error = false
    unless cbts.nil?
      cbts.each do |tier|
        if tier.start != start
          errors.add(:chargeback_tiers, "must include all values from 0 to ∞ once.")
          error = true
          break
        else
          start = tier.end
          if tier.end == Float::INFINITY
            tier_ends = true
          end
        end
      end
      unless tier_ends || error
        errors.add(:chargeback_tiers, "must include all values from 0 to ∞.")
      end
    end
  end
end

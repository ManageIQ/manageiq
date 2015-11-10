class ChargebackRateDetail < ApplicationRecord
  belongs_to :chargeback_rate
  belongs_to :detail_measure, :class_name => "ChargebackRateDetailMeasure", :foreign_key => :chargeback_rate_detail_measure_id
  belongs_to :detail_currency, :class_name => "ChargebackRateDetailCurrency", :foreign_key => :chargeback_rate_detail_currency_id

  validates :rate, :numericality => true
  validates :group, :source, :presence => true

  def cost(value)
    return 0.0 unless self.enabled?
    value = 1 if group == 'fixed'

    value * hourly_rate
  end

  def hourly_rate
    rate = self.rate.to_s.to_f
    return 0.0 if rate.zero?

    hr = case per_time
         when "hourly"  then rate
         when "daily"   then rate / 24
         when "weekly"  then rate / 24 / 7
         when "monthly" then rate / 24 / 30
         when "yearly"  then rate / 24 / 365
         else raise "rate time unit of '#{per_time}' not supported"
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
    value = read_attribute(:friendly_rate)
    return value unless value.nil?

    if group == 'fixed'
      # Example: 10.00 Monthly
      "#{rate} #{per_time.to_s.capitalize}"
    else
      # Example: Daily @ .02 per MHz
      "#{per_time.to_s.capitalize} @ #{rate} per #{per_unit_display}"
    end
  end

  def per_unit_display
    detail_measure.nil? ? per_unit.to_s.capitalize : detail_measure.measures.key(per_unit)
  end

  def rate_type
    # Return parent's rate type
    chargeback_rate.rate_type unless chargeback_rate.nil?
  end
end

class ChargebackRateDetail < ActiveRecord::Base
  belongs_to :chargeback_rate
  validates_numericality_of :rate

  def cost(value)
    return 0.0 unless self.enabled?
    value = 1 if self.group == 'fixed'

    value * self.hourly_rate()
  end

  def hourly_rate()
    rate = self.rate.to_s.to_f
    return 0.0 if rate.zero?

    hr = case self.per_time
    when "hourly"  then rate
    when "daily"   then rate / 24
    when "weekly"  then rate / 24 / 7
    when "monthly" then rate / 24 / 30
    when "yearly"  then rate / 24 / 365
    else raise "rate time unit of '#{self.per_time}' not supported"
    end

    # Handle cases where we need to adjust per_unit to a common value.
    self.rate_adjustment(hr)
  end

  def rate_adjustment(hr)
    case self.per_unit
    when "gigabytes" then hr / 1.gigabyte   # adjust to bytes / per hour
    else hr
    end
  end

  def rate_name
    "#{self.group}_#{self.source}"
  end

  def friendly_rate
    value = read_attribute(:friendly_rate)
    return value unless value.nil?

    if self.group == 'fixed'
      # Example: 10.00 Monthly
      "#{self.rate} #{self.per_time.to_s.capitalize}"
    else
      # Example: Daily @ .02 per MHz
      "#{self.per_time.to_s.capitalize} @ #{self.rate} per #{self.per_unit_display}"
    end
  end

  def per_unit_display
    case self.per_unit
    when 'megahertz' then 'MHz'
    when 'megabytes' then 'MB'
    when 'gigabytes' then 'GB'
    when 'kbps' then 'KBps'
    else self.per_unit.to_s.capitalize
    end
  end

  def rate_type
    # Return parent's rate type
   self.chargeback_rate.rate_type unless self.chargeback_rate.nil?
  end
end

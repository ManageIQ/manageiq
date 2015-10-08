class ChargebackRateDetail < ActiveRecord::Base
  belongs_to :chargeback_rate
  validates_numericality_of :rate

  def cost(value)
    return 0.0 unless self.enabled?
    unless self.chargeback_tier_id.nil?
      tier = ChargebackTier.find_by_id(chargeback_tier_id)
      unless tier.nil?
        self.rate = tier.rate(value)
        hourly_rate = tiered_hourly_rate(value)
      end
    end
    value = 1 if group == 'fixed'
    hourly_rate ||= self.hourly_rate()
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

  def tiered_hourly_rate(value)
    tier = ChargebackTier.find_by_id(chargeback_tier_id)
    unless tier.nil?
      self.rate = tier.rate(value)
    end
    hourly_rate
  end

  def rate_adjustment(hr)
    case per_unit
    when "gigabytes" then hr / 1.gigabyte   # adjust to bytes / per hour
    else hr
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
    case per_unit
    when 'megahertz' then 'MHz'
    when 'megabytes' then 'MB'
    when 'gigabytes' then 'GB'
    when 'kbps' then 'KBps'
    else per_unit.to_s.capitalize
    end
  end

  def rate_type
    # Return parent's rate type
    chargeback_rate.rate_type unless chargeback_rate.nil?
  end
end

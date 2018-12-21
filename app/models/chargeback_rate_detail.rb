class ChargebackRateDetail < ApplicationRecord
  belongs_to :chargeback_rate
  belongs_to :chargeable_field
  belongs_to :detail_measure, :class_name => "ChargebackRateDetailMeasure", :foreign_key => :chargeback_rate_detail_measure_id
  belongs_to :detail_currency, :class_name => "ChargebackRateDetailCurrency", :foreign_key => :chargeback_rate_detail_currency_id
  has_many :chargeback_tiers, :dependent => :destroy, :autosave => true

  default_scope { joins(:chargeable_field).merge(ChargeableField.order(:group => :asc, :description => :asc)) }

  validates :chargeback_rate, :chargeable_field, :presence => true
  validate :contiguous_tiers?

  delegate :rate_type, :to => :chargeback_rate, :allow_nil => true

  delegate :metric_column_key, :metric_key, :cost_keys, :rate_key, :to => :chargeable_field

  FORM_ATTRIBUTES = %i(description per_time per_unit metric group source metric chargeable_field_id sub_metric).freeze
  PER_TIME_TYPES = {
    "hourly"  => _("Hourly"),
    "daily"   => _("Daily"),
    "weekly"  => _("Weekly"),
    "monthly" => _("Monthly"),
    'yearly'  => _('Yearly')
  }.freeze

  # gigabytes -> GiB
  #
  def showback_unit(p_per_unit = nil)
    return '' unless chargeable_field.detail_measure
    {'bytes'     => '',
     'kilobytes' => 'KiB',
     'megabytes' => 'MiB',
     'gigabytes' => 'GiB',
     'terabytes' => 'TiB',
     'hertz'     => '',
     'kilohertz' => 'KHz',
     'megahertz' => 'MHz',
     'gigahertz' => 'GHz',
     'teraherts' => 'THz',
     'bps'       => '',
     'kbps'      => 'Mbps',
     'mbps'      => 'Gbps',
     'gbps'      => 'Tbps'}[p_per_unit || per_unit]
  end

  def populate_showback_rate(plan, rate_detail, entity)
    group = rate_detail.chargeable_field.showback_measure
    field, _, calculation = rate_detail.chargeable_field.showback_dimension
    unit  = rate_detail.showback_unit

    showback_rate = ManageIQ::Showback::Rate.find_or_create_by(:entity      => entity,
                                                               :group       => group,
                                                               :field       => field,
                                                               :price_plan  => plan,
                                                               :calculation => calculation,
                                                               :concept     => rate_detail.id)
    showback_rate.tiers.destroy_all
    rate_detail.chargeback_tiers.each do |tier|
      showback_rate.tiers.build(:tier_start_value       => tier.start,
                                :tier_end_value         => tier.finish,
                                :variable_rate_per_time => rate_detail.per_time,
                                :variable_rate_per_unit => unit,
                                :fixed_rate_per_time    => rate_detail.per_time,
                                :fixed_rate             => Money.new(tier.fixed_rate * Money.default_currency.subunit_to_unit),
                                :variable_rate          => Money.new(tier.variable_rate * Money.default_currency.subunit_to_unit))
    end
    showback_rate.save
  end

  def sub_metrics
    if metric == 'derived_vm_allocated_disk_storage'
      volume_types = CloudVolume.volume_types
      unless volume_types.empty?
        res = {}
        res[_('All')] = ''
        volume_types.each { |type| res[type.capitalize] = type }
        res[_('Other - Unclassified')] = 'unclassified'
        res
      end
    end
  end

  def sub_metric_human
    sub_metric.present? ? sub_metric.capitalize : 'All'
  end

  def rate_values(consumption, options)
    fixed_rate, variable_rate = find_rate(chargeable_field.measure(consumption, options, sub_metric))
    hourly_fixed_rate         = hourly(fixed_rate, consumption)
    hourly_variable_rate      = hourly(variable_rate, consumption)

    "#{hourly_fixed_rate}/#{hourly_variable_rate}"
  end

  def charge(consumption, options)
    result = {}

    metric_value, cost = metric_and_cost_by(consumption, options)
    if !consumption.chargeback_fields_present && chargeable_field.fixed?
      cost = 0
    end

    result[rate_key(sub_metric)] = rate_values(consumption, options)
    result[metric_key(sub_metric)] = metric_value
    cost_keys(sub_metric).each { |field| result[field] = cost }

    result
  end

  # Set the rates according to the tiers
  def find_rate(value)
    @found_rates ||= {}
    @found_rates[value] ||=
      begin
        fixed_rate = 0.0
        variable_rate = 0.0
        tier_found = chargeback_tiers.detect { |tier| tier.includes?(value * rate_adjustment) }
        unless tier_found.nil?
          fixed_rate = tier_found.fixed_rate
          variable_rate = tier_found.variable_rate
        end

        [fixed_rate, variable_rate]
      end
  end

  PER_TIME_MAP = {
    :hourly  => "Hour",
    :daily   => "Day",
    :weekly  => "Week",
    :monthly => "Month",
    :yearly  => "Year"
  }

  def hourly_cost(value, consumption)
    return 0.0 unless self.enabled?

    (fixed_rate, variable_rate) = find_rate(value)

    hourly_fixed_rate    = hourly(fixed_rate, consumption)
    hourly_variable_rate = hourly(variable_rate, consumption)

    hourly_fixed_rate + rate_adjustment * value * hourly_variable_rate
  end

  def hourly(rate, consumption)
    hourly_rate = case per_time
                  when "hourly"  then rate
                  when "daily"   then rate / 24
                  when "weekly"  then rate / 24 / 7
                  when "monthly" then rate / consumption.hours_in_month
                  when "yearly"  then rate / 24 / 365
                  else raise "rate time unit of '#{per_time}' not supported"
                  end

    hourly_rate
  end

  def rate_adjustment
    @rate_adjustment ||= chargeable_field.adjustment_to(per_unit)
  end

  def affects_report_fields(report_cols)
    ([metric_key].to_set & report_cols).present? || ((cost_keys.to_set & report_cols).present? && !gratis?)
  end

  def friendly_rate
    (fixed_rate, variable_rate) = find_rate(0.0)
    value = read_attribute(:friendly_rate)
    return value unless value.nil?

    if chargeable_field.fixed?
      # Example: 10.00 Monthly
      "#{fixed_rate + variable_rate} #{per_time.to_s.capitalize}"
    else
      s = ""
      chargeback_tiers.each do |tier|
        # Example: Daily @ .02 per MHz from 0.0 to Infinity
        s += "#{per_time.to_s.capitalize} @ #{tier.fixed_rate} + "\
             "#{tier.variable_rate} per #{per_unit_display} from #{tier.start} to #{tier.finish}\n"
      end
      s.chomp
    end
  end

  def per_unit_display
    measure = chargeable_field.detail_measure
    measure.nil? ? per_unit.to_s.capitalize : measure.measures.key(per_unit)
  end

  # New method created in order to show the rates in a easier to understand way
  def show_rates
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
    tiers = chargeback_tiers

    tiers.each_with_index do |tier, index|
      if single_tier?(tier,tiers)
        error = true if !tier.starts_with_zero? || !tier.ends_with_infinity?
      elsif first_tier?(tier,tiers)
        error = true if !tier.starts_with_zero? || tier.ends_with_infinity?
      elsif last_tier?(tier,tiers)
        error = true if !consecutive_tiers?(tier, tiers[index - 1]) || !tier.ends_with_infinity?
      elsif middle_tier?(tier,tiers)
        error = true if !consecutive_tiers?(tier, tiers[index - 1]) || tier.ends_with_infinity?
      end

      break if error
    end

    errors.add(:chargeback_tiers, _("must start at zero and not contain any gaps between start and prior end value.")) if error

    !error
  end

  private

  def gratis?
    chargeback_tiers.all?(&:gratis?)
  end

  def metric_and_cost_by(consumption, options)
    metric_value = chargeable_field.measure(consumption, options, sub_metric)
    hourly_cost = hourly_cost(metric_value, consumption)

    _log.debug("Consumption interval: #{consumption.consumption_start} -  #{consumption.consumption_end}")
    _log.debug("Consumed hours: #{consumption.consumed_hours_in_interval}")
    cost = chargeable_field.metering? ? hourly_cost : hourly_cost * consumption.consumed_hours_in_interval
    [metric_value, cost]
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
      next unless chargeback_rate[:rate_type] == rate_type && chargeback_rate[:description] == "Default"

      chargeback_rate[:rates].each do |detail|
        detail_new = ChargebackRateDetail.new(detail.slice(*ChargebackRateDetail::FORM_ATTRIBUTES))
        detail_new.detail_currency = ChargebackRateDetailCurrency.find_by(:name => detail[:type_currency])
        detail_new.metric = detail[:metric]
        detail_new.chargeable_field = ChargeableField.find_by(:metric => detail.delete(:metric))

        detail[:tiers].sort_by { |tier| tier[:start] }.each do |tier|
          detail_new.chargeback_tiers << ChargebackTier.new(tier.slice(*ChargebackTier::FORM_ATTRIBUTES))
        end

        rate_details.push(detail_new)

        if detail_new.chargeable_field.metric == 'derived_vm_allocated_disk_storage'
          volume_types = CloudVolume.volume_types
          volume_types.push('unclassified') if volume_types.present?
          volume_types.each do |volume_type|
            storage_detail_new = detail_new.dup
            storage_detail_new.sub_metric = volume_type
            detail[:tiers].sort_by { |tier| tier[:start] }.each do |tier|
              storage_detail_new.chargeback_tiers << ChargebackTier.new(tier.slice(*ChargebackTier::FORM_ATTRIBUTES))
            end
            rate_details.push(storage_detail_new)
          end
        end
      end
    end

    rate_details.sort_by { |rd| [rd.chargeable_field[:group], rd.chargeable_field[:description], rd[:sub_metric].to_s] }
  end
end

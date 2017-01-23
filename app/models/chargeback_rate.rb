class ChargebackRate < ApplicationRecord
  include UuidMixin

  ASSIGNMENT_PARENT_ASSOCIATIONS = [:host, :ems_cluster, :storage, :ext_management_system, :my_enterprise]

  ################################################################################
  # NOTE:                                                                        #
  # ensure_unassigned must occur before the taggings relation is destroyed,      #
  # since it uses the taggings for its calculation.  The :dependent => :destroy  #
  # on taggings is part of the destroy callback chain, so we must define this    #
  # before_destroy here, before that relation is defined, otherwise the callback #
  # chain is out of order.  The taggings relation is defined in ar_taggable.rb,  #
  # and is brought in by the call to acts_as_miq_taggable in the AssignmentMixin #
  ################################################################################
  before_destroy :ensure_unassigned
  before_destroy :ensure_nondefault

  include AssignmentMixin

  has_many :chargeback_rate_details, :dependent => :destroy, :autosave => true

  validates_presence_of     :description, :guid
  validates_uniqueness_of   :guid
  validates_uniqueness_of   :description, :scope => :rate_type

  delegate :symbol, :to => :currency, :prefix => true, :allow_nil => true

  VALID_CB_RATE_TYPES = ["Compute", "Storage"]

  def rate_details_relevant_to(report_cols)
    # we can memoize, as we get the same report_cols thrrough the life of the object
    @relevant ||= chargeback_rate_details.select { |r| r.affects_report_fields(report_cols) }
  end

  def self.validate_rate_type(type)
    unless VALID_CB_RATE_TYPES.include?(type.to_s.capitalize)
      raise "Chargeback rate type '#{type}' is not supported"
    end
  end

  def self.get_assignments(type)
    # type = :compute || :storage
    # Returns[{:cb_rate=>obj, :tag=>[Classification.entry_object, klass]} || :object=>object},...]
    validate_rate_type(type)
    result = []
    ChargebackRate.where(:rate_type => type.to_s.capitalize).each do |rate|
      assigned_tos = rate.get_assigned_tos
      assigned_tos[:tags].each    { |tag|    result << {:cb_rate => rate, :tag => tag} }
      assigned_tos[:objects].each { |object| result << {:cb_rate => rate, :object => object} }
      assigned_tos[:labels].each  { |label|  result << {:cb_rate => rate, :label => label} }
    end
    result
  end

  def self.set_assignments(type, cb_rates)
    validate_rate_type(type)
    ChargebackRate.where(:rate_type => type.to_s.capitalize).each(&:remove_all_assigned_tos)

    cb_rates.each do |rate|
      rate[:cb_rate].assign_to_objects(rate[:object]) if rate.key?(:object)
      rate[:cb_rate].assign_to_tags(*rate[:tag])      if rate.key?(:tag)
      rate[:cb_rate].assign_to_labels(*rate[:label])  if rate.key?(:label)
    end
  end

  def self.seed
    # seeding the measure fixture before seed the chargeback rates fixtures
    ChargebackRateDetailMeasure.seed_measures
    ChargeableField.seed_fields # Cannot use seed order until we refactor seed_chargeback_rate_measure
    ChargebackRateDetailCurrency.seed_currencies
    seed_chargeback_rate
  end

  def self.seed_chargeback_rate
    # seeding the rates fixtures
    fixture_file = File.join(FIXTURE_DIR, "chargeback_rates.yml")
    if File.exist?(fixture_file)
      fixture = YAML.load_file(fixture_file)
      fix_mtime = File.mtime(fixture_file).utc
      fixture.each do |cbr|
        rec = find_by(:guid => cbr[:guid])
        rates = cbr.delete(:rates)

        # The yml measure field is the name of the measure. It's changed to the id
        rates.each do |rate_detail|
          measure = ChargebackRateDetailMeasure.find_by(:name => rate_detail.delete(:measure))
          currency = ChargebackRateDetailCurrency.find_by(:name => rate_detail.delete(:type_currency))
          metric = rate_detail[:metric] || "#{rate_detail[:group]}_#{rate_detail[:source]}"
          field = ChargeableField.find_by(:metric => metric)
          rate_detail[:chargeable_field_id] = field.id
          unless measure.nil?
            rate_detail[:chargeback_rate_detail_measure_id] = measure.id
          end
          if currency
            rate_detail[:chargeback_rate_detail_currency_id] = currency.id
          end
          rate_tiers = []
          tiers = rate_detail.delete(:tiers)
          tiers.each do |tier|
            tier_start = ChargebackTier.to_float(tier.delete(:start))
            tier_finish = ChargebackTier.to_float(tier.delete(:finish))
            fixed_rate = tier.delete(:fixed_rate)
            variable_rate = tier.delete(:variable_rate)
            cbt = ChargebackTier.create(:start => tier_start, :finish => tier_finish, :fixed_rate => fixed_rate, :variable_rate => variable_rate)
            rate_tiers.append(cbt)
          end
          rate_detail[:chargeback_tiers] = rate_tiers
        end
        if rec.nil?
          _log.info("Creating [#{cbr[:description]}] with guid=[#{cbr[:guid]}]")
          rec = create(cbr)
          rec.chargeback_rate_details.create(rates)
        else
          if fix_mtime > rec.created_on
            _log.info("Updating [#{cbr[:description]}] with guid=[#{cbr[:guid]}]")
            rec.update_attributes(cbr)
            rec.chargeback_rate_details.clear
            rec.chargeback_rate_details.create(rates)
            rec.created_on = fix_mtime
            rec.save
          end
        end
      end
    end
  end

  def assigned?
    get_assigned_tos != {:objects => [], :tags => [], :labels => []}
  end

  def assigned_tags
    get_assigned_tos[:tags].map do |x|
      classification_entry_object = x.first
      classification_entry_object.tag.send(:name_path)
    end
  end

  def assigned_tags?
    get_assigned_tos[:tags].present?
  end

  ###########################################################

  private

  def currency
    # Note that the currency should be relation to ChargebackRate, not ChargebackRateDetail. We cannot work
    # with various currencies within single ChargebackRate. This is to be fixed later in series of db migrations.
    chargeback_rate_details.first.try(:detail_currency)
  end

  def ensure_unassigned
    if assigned?
      errors.add(:rate, "rate is assigned and cannot be deleted")
      throw :abort
    end
  end

  def ensure_nondefault
    if default?
      errors.add(:rate, "default rate cannot be deleted")
      throw :abort
    end
  end
end

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

  validates :description, :presence => true, :uniqueness_when_changed => {:scope => :rate_type}

  delegate :symbol, :to => :currency, :prefix => true, :allow_nil => true

  scope :with_rate_type, ->(rate_type) { where(:rate_type => rate_type) }

  virtual_column :assigned_to, :type => :string_set

  VALID_CB_RATE_TYPES = ["Compute", "Storage"]
  DATASTORE_MAPPING   = {'CloudVolume' => 'Storage'}.freeze

  def self.tag_class(klass)
    klass = ChargebackRate::DATASTORE_MAPPING[klass] || klass
    super(klass)
  end

  def rate_details_relevant_to(report_cols, allowed_cols)
    # we can memoize, as we get the same report_cols through the life of the object
    @relevant ||= begin
      chargeback_rate_details.select do |r|
        r.affects_report_fields(report_cols) && allowed_cols.include?(r.metric_column_key)
      end
    end
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

  def self.unassign_rate_assignments(type, cb_rates)
    validate_rate_type(type)

    cb_rates.each do |rate|
      rate[:cb_rate].unassign_objects(rate[:object]) if rate.key?(:object)
      rate[:cb_rate].unassign_tags(*rate[:tag])      if rate.key?(:tag)
      rate[:cb_rate].unassign_labels(*rate[:label])  if rate.key?(:label)
    end
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
    fixture_file = File.join(FIXTURE_DIR, "chargeback_rates.yml")
    if File.exist?(fixture_file)
      fixture = YAML.load_file(fixture_file)
      fix_mtime = File.mtime(fixture_file).utc
      fixture.each do |cbr|
        rec = find_by(:guid => cbr[:guid])
        rates = cbr.delete(:rates)

        rates.each do |rate_detail|
          currency = Currency.find_by(:code => rate_detail.delete(:type_currency))
          field = ChargeableField.find_by(:metric => rate_detail.delete(:metric))
          rate_detail[:chargeable_field_id] = field.id
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
            rec.update(cbr)
            rec.chargeback_rate_details.clear
            rec.chargeback_rate_details.create(rates)
            rec.created_on = fix_mtime
            rec.save!
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

  def default?
    super || description == 'Default Container Image Rate'
  end

  def assigment_type_description(record, type)
    assignment_key = if %i[object storage].include?(type)
                       record.kind_of?(MiqEnterprise) ? "enterprise" : record.class.table_name.singularize
                     elsif type == :tag
                       "#{record&.second}-tags"
                     elsif type == :label
                       "container_image-labels"
                     end
    rate_type_for_tos = rate_type == "Compute" ? :chargeback_compute : :chargeback_storage
    TermOfServiceHelper::ASSIGN_TOS[rate_type_for_tos][assignment_key] || raise("'#{assignment_key}' as chargeback assignment type is not supported for #{rate_type_for_tos} rate.")
  end

  def assigned_to
    result = []

    tos = get_assigned_tos
    tos[:tags].each { |tag| result << {:tag => tag, :assigment_type_description => assigment_type_description(tag, :tag)} }
    tos[:objects].each { |object| result << {:object => object, :assigment_type_description => assigment_type_description(object, :object)} }
    tos[:labels].each { |label| result << {:label => label, :assigment_type_description => assigment_type_description(label, :label)} }

    result
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

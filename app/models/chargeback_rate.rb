class ChargebackRate < ActiveRecord::Base
  include UuidMixin
  include ReportableMixin

  ASSIGNMENT_PARENT_ASSOCIATIONS = [:host, :ems_cluster, :storage, :ext_management_system, :my_enterprise]
  include AssignmentMixin

  has_many :chargeback_rate_details, :dependent => :destroy

  validates_presence_of     :description, :guid
  validates_uniqueness_of   :guid
  validates_uniqueness_of   :description, :scope => :rate_type

  FIXTURE_DIR = File.join(Rails.root, "db/fixtures")

  VALID_CB_RATE_TYPES = ["Compute", "Storage"]

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
    end
    result
  end

  def self.set_assignments(type, cb_rates)
    validate_rate_type(type)
    ChargebackRate.where(:rate_type => type.to_s.capitalize).each(&:remove_all_assigned_tos)

    cb_rates.each do |rate|
      rate[:cb_rate].assign_to_objects(rate[:object]) if rate.key?(:object)
      rate[:cb_rate].assign_to_tags(*rate[:tag])      if rate.key?(:tag)
    end
  end

  def self.seed
    #seeding the chargeback_rate_detail_currencies
    fixture_file = File.join(FIXTURE_DIR, "chargeback_rate_detail_currencies.yml")
    if File.exist?(fixture_file)
      fixture = YAML.load_file(fixture_file)
      fixture.each do |cbr|
        rec = ChargebackRateDetailCurrency.find_by_name(cbr[:name])
        if rec.nil?
          _log.info("Creating [#{cbr[:name]}] with symbols=[#{cbr[:symbol]}]!!!!")
          rec = ChargebackRateDetailCurrency.create(cbr)
        else
          fixture_mtime = File.mtime(fixture_file).utc
          if fixture_mtime > rec.created_at
            _log.info("Updating [#{cbr[:name]}] with symbols=[#{cbr[:symbol]}]")
            rec.update_attributes(cbr)
            rec.created_at = fixture_mtime
            rec.save
          end
        end
      end
    end
    #seeding the rates fixtures
    fixture_file = File.join(FIXTURE_DIR, "chargeback_rates.yml")
    if File.exist?(fixture_file)
      fixture = YAML.load_file(fixture_file)

      fixture.each do |cbr|
        rec = find_by_guid(cbr[:guid])
        rates = cbr.delete(:rates)
        #seeding the chargeback_rate_detail_currencies
        rates.each do |rate|
            currency = ChargebackRateDetailCurrency.find_by(name: rate.delete(:type_currency))
            _log.info("Creating"+ currency.inspect)
            if not currency.nil?
              rate[:chargeback_rate_detail_currency_id]=currency.id
            end
          end
        if rec.nil?
          _log.info("Creating [#{cbr[:description]}] with guid=[#{cbr[:guid]}]")
          rec = create!(cbr)
          rec.chargeback_rate_details.create(rates)
        else
          fixture_mtime = File.mtime(fixture_file).utc
          if fixture_mtime > rec.created_on
            _log.info("Updating [#{cbr[:description]}] with guid=[#{cbr[:guid]}]")
            rec.update_attributes(cbr)
            rec.chargeback_rate_details.clear
            rec.chargeback_rate_details.create(rates)
            rec.created_on = fixture_mtime
            rec.save!
          end
        end
      end
    end
  end
end

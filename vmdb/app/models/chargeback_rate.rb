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
    #Returns[{:cb_rate=>obj, :tag=>[Classification.entry_object, klass]} || :object=>object},...]
    self.validate_rate_type(type)
    result = []
    ChargebackRate.find(:all, :conditions => {:rate_type => type.to_s.capitalize}).each do |rate|
      assigned_tos = rate.get_assigned_tos
      assigned_tos[:tags].each    {|tag|    result << {:cb_rate => rate, :tag => tag}}
      assigned_tos[:objects].each {|object| result << {:cb_rate => rate, :object => object}}
    end
    return result
  end

  def self.set_assignments(type,cb_rates)
    #cb_rates = [{:cb_rate=>obj, :tag=>[Classification.entry_object, klass]} || :object=>object},...]
    #cb_rates.each {|rate| rate[:cb_rate].remove_all_assigned_tos}
    self.validate_rate_type(type)
    ChargebackRate.find(:all, :conditions => {:rate_type => type.to_s.capitalize}).each do |rate|
      rate.remove_all_assigned_tos
    end

    cb_rates.each do |rate|
      rate[:cb_rate].assign_to_objects(rate[:object]) if rate.has_key?(:object)
      rate[:cb_rate].assign_to_tags(*rate[:tag])      if rate.has_key?(:tag)
    end
  end

  def self.seed
    MiqRegion.my_region.lock do
      fixture_file = File.join(FIXTURE_DIR, "chargeback_rates.yml")
      if File.exist?(fixture_file)
        fixture = YAML.load_file(fixture_file)

        fixture.each do |cbr|
          rec = self.find_by_guid(cbr[:guid])
          rates = cbr.delete(:rates)
          if rec.nil?
            $log.info("MIQ(ChargebackRate.seed) Creating [#{cbr[:description]}] with guid=[#{cbr[:guid]}]")
            rec = self.create(cbr)
            rec.chargeback_rate_details.create(rates)
          else
            fixture_mtime = File.mtime(fixture_file).utc
            if fixture_mtime > rec.created_on
              $log.info("MIQ(ChargebackRate.seed) Updating [#{cbr[:description]}] with guid=[#{cbr[:guid]}]")
              rec.update_attributes(cbr)
              rec.chargeback_rate_details.clear
              rec.chargeback_rate_details.create(rates)
              rec.created_on = fixture_mtime
              rec.save
            end
          end
        end
      end
    end
  end
end

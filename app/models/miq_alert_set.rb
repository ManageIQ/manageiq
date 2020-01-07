class MiqAlertSet < ApplicationRecord
  acts_as_miq_set

  before_validation :default_name_to_description, :on => :create

  include AssignmentMixin

  virtual_has_one :get_assigned_tos

  def self.assigned_to_target(target, options = {})
    get_assigned_for_target(target, options)
  end

  def notes
    set_data[:notes] if set_data.kind_of?(Hash) && set_data.key?(:notes)
  end

  def notes=(data)
    return if data.nil?
    self.set_data ||= {}
    self.set_data[:notes] = data[0..511]
  end

  def active?
    !members.all? { |p| !p.active }
  end

  def export_to_array
    [self.class.to_s => ContentExporter.export_to_hash(attributes, "MiqAlert", members)]
  end

  def export_to_yaml
    export_to_array.to_yaml
  end

  def self.import_from_hash(alert_profile, options = {})
    ContentImporter.import_from_hash(MiqAlertSet, MiqAlert, alert_profile, options)
  end

  def self.import_from_yaml(fd, options = {})
    input = YAML.load(fd)
    input.collect do |e|
      _a, stat = import_from_hash(e["MiqAlertSet"], options)
      stat
    end
  end

  def self.seed
    fixture_file = File.join(FIXTURE_DIR, "miq_alert_sets.yml")
    return unless File.exist?(fixture_file)
    File.open(fixture_file) { |fd| MiqAlertSet.import_from_yaml(fd, :save => true) }
  end

  def self.display_name(number = 1)
    n_('Alert Profile', 'Alert Profiles', number)
  end

  private

  def default_name_to_description
    self.name ||= description
  end
end

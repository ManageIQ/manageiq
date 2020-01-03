class MiqPolicySet < ApplicationRecord
  acts_as_miq_set

  before_validation :default_name_to_description, :on => :create
  before_destroy    :destroy_policy_tags

  attr_accessor :reserved

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

  def destroy_policy_tags
    # handle policy assignment removal for deleted policy profile
    Tag.find_by(:name => "/miq_policy/assignment/#{self.class.to_s.underscore}/#{id}").try!(:destroy)
  end

  def add_policy(policy)
    add_member(policy)
  end

  def remove_policy(policy)
    remove_member(policy)
  end

  def get_policies
    miq_policies
  end

  def add_to(ids, db)
    operation_on_multiple(ids, db, :add_policy)
  end

  def remove_from(ids, db)
    operation_on_multiple(ids, db, :remove_policy)
  end

  private def operation_on_multiple(ids, db, operation)
    model = db.respond_to?(:constantize) ? db.constantize : db
    model.where(:id => ids).each do |rec|
      rec.send(operation, self)
    end
  end

  def export_to_array
    [self.class.to_s => ContentExporter.export_to_hash(attributes, "MiqPolicy", members)]
  end

  def export_to_yaml
    export_to_array.to_yaml
  end

  def self.import_from_hash(policy_profile, options = {})
    ContentImporter.import_from_hash(MiqPolicySet, MiqPolicy, policy_profile, options)
  end

  def self.import_from_yaml(fd)
    input = YAML.load(fd)
    input.collect do |e|
      _p, stat = import_from_hash(e["MiqPolicySet"])
      stat
    end
  end

  def self.seed
    fixture_file = File.join(FIXTURE_DIR, "miq_policy_sets.yml")
    fixtures = File.exist?(fixture_file) ? YAML.load_file(fixture_file) : []
    MiqPolicy.import_from_array(fixtures, :save => true)

    all.each do |ps|
      if ps.mode.nil?
        _log.info("Updating [#{ps.name}]")
        ps.update_attribute(:mode, "control")
      end
    end
  end

  def self.display_name(number = 1)
    n_('Policy Profile', 'Policy Profiles', number)
  end

  private

  def default_name_to_description
    self.name ||= description
  end
end # class MiqPolicySet

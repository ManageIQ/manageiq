class MiqAeDomain < MiqAeNamespace
  default_scope { where(:parent_id => nil).where(arel_table[:name].not_eq("$")) }
  validates_inclusion_of :parent_id, :in => [nil], :message => 'should be nil for Domain'
  # TODO: Once all the specs start passing in the tenant object, enforce its presence
  validates_presence_of :tenant, :message => "object is needed to own the domain"
  after_destroy :squeeze_priorities
  default_value_for :system,  false
  default_value_for :enabled, false
  before_save :default_priority
  belongs_to :tenant

  EXPORT_EXCLUDE_KEYS = [/^id$/, /^(?!tenant).*_id$/, /^created_on/, /^updated_on/, /^updated_by/, /^reserved$/]

  include TenancyMixin

  def self.enabled
    where(:enabled => true)
  end

  def self.reset_priority_by_ordered_ids(ids)
    ids.each_with_index do |id, priority|
      MiqAeDomain.find_by!(:id => id).update_attributes(:priority => priority + 1)
    end
  end

  def self.highest_priority(tenant)
    MiqAeDomain.where(:tenant => tenant).maximum('priority').to_i
  end

  def default_priority
    self.priority = MiqAeDomain.highest_priority(tenant) + 1 unless priority
  end

  def version
    system = ae_namespaces.detect { |ns| ns.name.downcase == 'system' }
    about = system.try(:ae_classes).try(:detect) { |cls| cls.name.downcase == 'about' }
    version_field = about.try(:ae_fields).try(:detect) { |fld| fld.name == 'version' }
    version_field.try(:default_value)
  end

  def available_version
    fname = about_file_name.to_s
    return nil unless File.exist?(fname)
    class_yaml = YAML.load_file(fname)
    fields = class_yaml.fetch_path('object', 'schema') if class_yaml.kind_of?(Hash)
    version_field = fields.try(:detect) { |f| f.fetch_path('field', 'name') == 'version' }
    version_field.try(:fetch_path, 'field', 'default_value')
  end

  private

  def squeeze_priorities
    ids = MiqAeDomain.where('priority > 0', :tenant => tenant).order('priority ASC').collect(&:id)
    MiqAeDomain.reset_priority_by_ordered_ids(ids)
  end

  def self.any_unlocked?
    MiqAeDomain.where('system is null OR system = ?', [false]).count > 0
  end

  def self.all_unlocked
    MiqAeDomain.where('system is null OR system = ?', [false]).order('priority DESC')
  end

  def about_file_name
    system = ae_namespaces.detect { |ns| ns.name.downcase == 'system' }
    about = system.try(:ae_classes).try(:detect) { |cls| cls.name.downcase == 'about' }

    File.join(MiqAeDatastore::DATASTORE_DIRECTORY, name, system.name,
              "#{about.name}#{CLASS_DIR_SUFFIX}", CLASS_YAML_FILENAME) if about
  end
end

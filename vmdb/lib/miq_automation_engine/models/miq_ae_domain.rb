class MiqAeDomain < MiqAeNamespace
  include MiqAeCount
  include MiqAeFindByName
  include MiqAeDefault

  expose_columns :parent_id, :system, :enabled, :priority
  expose_columns :description, :display_name, :name
  expose_columns :id
  expose_columns :created_on, :created_by_user_id
  expose_columns :updated_on, :updated_by, :updated_by_user_id

  validate      :uniqueness_of_domain_name, :on => :create
  validates_inclusion_of :parent_id, :in => [nil]

  ae_default_value_for(:enabled,  :value => true, :allow_nil => false)
  ae_default_value_for(:system,   :value => false)
  ae_default_value_for(:priority, :value => proc { MiqAeDomain.highest_priority + 1 })

  def uniqueness_of_domain_name
    errors.add(:name, "domain name #{name} is already in use") unless self.class.find_by_fqname(name).nil?
  end

  def self.enabled
    all_domains.select(&:enabled)
  end

  def self.highest_priority
    all_domains.max_by(&:priority).try(:priority).to_i
  end

  def self.reset_priority_by_ordered_ids(ids)
    ids.each_with_index do |id, priority|
      find(id).try(:update_attributes, :priority => priority + 1)
    end
  end

  def self.squeeze_priorities
    ids = all_domains.select { |d| d.priority > 0 }.collect(&:id)
    reset_priority_by_ordered_ids(ids)
  end

  def save
    context = persisted? ? :update : :create
    return false unless valid?(context)
    generate_id   unless id
    ae_defaults
    save_with_context(context)
  end

  def self.fqname_to_filename(fqname)
    "#{fqname}/#{DOMAIN_YAML_FILE}"
  end

  def generate_id
    self.id = self.class.fqname_to_id(name.downcase)
  end

  def destroy
    self.class.delete_directory(self.class.fs_name(fqname))
    self.class.squeeze_priorities
    self
  end

  def self.destroy(id)
    obj = MiqAeDomain.find(id)
    obj.destroy if obj
  end

  def self.all_unlocked
    all_domains.reverse.select { |d| d.system.nil? || !d.system }
  end

  def self.any_unlocked?
    all_domains.any? { |d| d.system.nil? || !d.system }
  end

  def self.all_domains
    fetch_domains.sort { |a, b| a.priority <=> b.priority }
  end

  def self.fetch_domains
    domain_list = []
    Dir.glob(File.join(MiqAeDatastore::DATASTORE_DIRECTORY, '*')).each do |entry|
      domain = File.basename(entry)
      next if domain == '$'
      filename = File.join(domain, MiqAeFsStore::DOMAIN_YAML_FILE)
      domain_list << find(domain) if file_exists?(filename)
    end
    domain_list
  end

  def self.find_by_name(name)
    fetch_by_name(name, MiqAeDomain)
  end

  def self.first
    find_by_name('*')
  end

  def self.order(string)
    attribute, order = string.downcase.split
    if order == 'asc'
      return fetch_domains.sort { |a, b| a.send(attribute) <=> b.send(attribute) }
    else
      return fetch_domains.sort { |b, a| a.send(attribute) <=> b.send(attribute) }
    end
  end

  def self.count
    fetch_count(MiqAeDomain)
  end

  private

  def save_with_context(context)
    self.priority  = self.class.highest_priority + 1 unless priority
    hash = setup_envelope(DOMAIN_OBJ_TYPE)
    self.class.git_repository(name, context == :create)
    entry = {:path => DOMAIN_YAML_FILE, :data => hash.to_yaml}
    write(context, entry).tap { |result| changes_applied if result }
  end

  def write(context, entry)
    if context == :update && changes.key?('name')
      @fqname = "/#{name}".downcase
      generate_id
      mv_domain_dir(changes['name'][0], entry)
    else
      self.class.add_files_to_repo(name, [entry])
    end
  end
end

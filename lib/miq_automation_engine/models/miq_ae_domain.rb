class MiqAeDomain < MiqAeNamespace
  SYSTEM_SOURCE = "system".freeze
  REMOTE_SOURCE = "remote".freeze
  USER_SOURCE   = "user".freeze
  USER_LOCKED_SOURCE = "user_locked".freeze
  VALID_SOURCES  = [SYSTEM_SOURCE, REMOTE_SOURCE, USER_SOURCE, USER_LOCKED_SOURCE].freeze
  LOCKED_SOURCES = [SYSTEM_SOURCE, REMOTE_SOURCE, USER_LOCKED_SOURCE].freeze
  EDITABLE_PROPERTIES_FOR_REMOTES = [:priority, :enabled].freeze
  AUTH_KEYS = %w(userid password).freeze

  default_scope { where(:parent_id => nil).where(arel_table[:name].not_eq("$")) }
  validates_inclusion_of :parent_id, :in => [nil], :message => 'should be nil for Domain'

  validates_presence_of :tenant, :message => "object is needed to own the domain"
  after_destroy :squeeze_priorities
  default_value_for :source,  USER_SOURCE
  default_value_for :enabled, false
  before_save :default_priority
  belongs_to :tenant
  belongs_to :git_repository, :dependent => :destroy
  validates_inclusion_of :source, :in => VALID_SOURCES

  EXPORT_EXCLUDE_KEYS = [/^id$/, /^(?!tenant).*_id$/, /^created_on/, /^updated_on/,
                         /^updated_by/, /^reserved$/, /^commit_message/,
                         /^commit_time/, /^commit_sha/, /^ref$/, /^ref_type$/,
                         /^last_import_on/].freeze

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

  def self.reset_priorities
    reset_priority_of_system_domains
    reset_priority_of_non_system_domains
  end

  def default_priority
    self.priority = MiqAeDomain.highest_priority(tenant) + 1 unless priority
  end

  def lock_contents!
    return if source == USER_LOCKED_SOURCE # already locked
    raise MiqAeException::CannotLock, "Cannot lock non user domains" unless source == USER_SOURCE
    self.source = USER_LOCKED_SOURCE
    save!
  end

  def unlock_contents!
    return if source == USER_SOURCE # already unlocked
    raise MiqAeException::CannotUnlock, "Cannot unlock non user domains" unless source == USER_LOCKED_SOURCE
    self.source = USER_SOURCE
    save!
  end

  def contents_locked?
    LOCKED_SOURCES.include?(source)
  end

  def lockable?
    editable_properties? && !contents_locked? && source == USER_SOURCE
  end

  def unlockable?
    editable_properties? && contents_locked? && source == USER_LOCKED_SOURCE
  end

  def editable_properties?
    source != SYSTEM_SOURCE
  end

  def editable_property?(property)
    case source
    when SYSTEM_SOURCE
      false
    when USER_SOURCE, USER_LOCKED_SOURCE
      true
    when REMOTE_SOURCE
      EDITABLE_PROPERTIES_FOR_REMOTES.include?(property.to_sym)
    else
      false
    end
  end

  alias editable_contents? editable?

  def version
    version_field = about_class.try(:ae_fields).try(:detect) { |fld| fld.name == 'version' }
    version_field.try(:default_value)
  end

  def available_version
    domain_path   = Vmdb::Plugins.instance.registered_automate_domains.detect { |d| d.name == name }.try(:path)
    domain_path ||= MiqAeDatastore::DATASTORE_DIRECTORY.join(name)
    self.class.version_from_schema(domain_path)
  end

  def self.version_from_schema(path)
    about_file = path.join("System/About#{CLASS_DIR_SUFFIX}/#{CLASS_YAML_FILENAME}")
    return unless about_file.file?
    class_yaml = YAML.load_file(about_file)
    fields = class_yaml.fetch_path('object', 'schema') if class_yaml.kind_of?(Hash)
    version_field = fields.try(:detect) { |f| f.fetch_path('field', 'name') == 'version' }
    version_field.try(:fetch_path, 'field', 'default_value')
  end

  def self.import_git_url(options)
    MiqAeGitImport.new(options).import
  end

  def self.import_git_repo(options)
    MiqAeGitImport.new(options).import
  end

  def update_git_info(git_repo, ref, ref_type)
    self.ref = ref
    self.git_repository = git_repo
    self.ref_type = ref_type
    info = latest_ref_info
    update_attributes!(:last_import_on => Time.now.utc,
                       :commit_sha     => info['commit_sha'],
                       :commit_message => info['commit_message'],
                       :commit_time    => info['commit_time'],
                       :source         => REMOTE_SOURCE)
  end

  def git_enabled?
    git_repository.present?
  end

  def git_repo_changed?
    commit_sha != latest_ref_info['commit_sha']
  end

  def latest_ref_info
    raise MiqAeException::InvalidDomain, "Not Git enabled" unless git_enabled?
    raise "No branch or tag selected for this domain" if ref.nil? && ref_type.nil?
    case ref_type
    when MiqAeGitImport::BRANCH
      git_repository.branch_info(ref)
    when MiqAeGitImport::TAG
      git_repository.tag_info(ref)
    end
  end

  def display_name
    return self[:display_name] unless git_enabled?
    "#{domain_name} (#{ref})"
  end

  def destroy_queue(user = User.current_user)
    raise ArgumentError, "User not provided, to destroy_queue" unless user

    task_options = {
      :action => "Destroy domain",
      :userid => user.userid
    }

    queue_options = {
      :class_name  => self.class.to_s,
      :method_name => "destroy",
      :instance_id => id,
      :role        => git_enabled? ? "git_owner" : nil,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_options, queue_options)
  end

  private

  def squeeze_priorities
    ids = MiqAeDomain.where('priority > 0', :tenant => tenant).order('priority ASC').collect(&:id)
    MiqAeDomain.reset_priority_by_ordered_ids(ids)
  end

  def self.any_enabled?
    MiqAeDomain.enabled.count > 0
  end

  def self.any_unlocked?
    MiqAeDomain.where(:source => USER_SOURCE).count > 0
  end

  def self.all_unlocked
    MiqAeDomain.where(:source => USER_SOURCE).order('priority DESC')
  end

  def about_class
    ns = MiqAeNamespace.where(:parent_id => id).find_by("lower(name) = ?", "system")
    MiqAeClass.where(:namespace_id => ns.id).find_by("lower(name) = ?", "about") if ns
  end

  def self.reset_priority_of_system_domains
    domains = MiqAeDomain.where('source = ? AND name <> ?',
                                SYSTEM_SOURCE,  MiqAeDatastore::MANAGEIQ_DOMAIN).order('name DESC')
    domains.each_with_index { |dom, index| dom.update_attributes(:priority => index + 1) }
  end

  private_class_method :reset_priority_of_system_domains

  def self.reset_priority_of_non_system_domains
    base = MiqAeDomain.where('source = ? AND name <> ?',
                             SYSTEM_SOURCE,  MiqAeDatastore::MANAGEIQ_DOMAIN).count
    domains = MiqAeDomain.where('source <> ?', SYSTEM_SOURCE)
    domains.each { |dom| dom.update_attributes(:priority => base + dom.priority) }
  end

  private_class_method :reset_priority_of_non_system_domains
end

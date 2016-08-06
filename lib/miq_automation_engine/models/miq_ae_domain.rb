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
  belongs_to :git_repository
  validates_inclusion_of :source, :in => VALID_SOURCES

  BRANCH = 'branch'.freeze
  TAG    = 'tag'.freeze
  DEFAULT_BRANCH = 'origin/master'.freeze

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
    fname = about_file_name
    return nil if fname.nil? || !File.exist?(fname)
    class_yaml = YAML.load_file(fname)
    fields = class_yaml.fetch_path('object', 'schema') if class_yaml.kind_of?(Hash)
    version_field = fields.try(:detect) { |f| f.fetch_path('field', 'name') == 'version' }
    version_field.try(:fetch_path, 'field', 'default_value')
  end

  def self.import_git_url(options)
    gr = GitRepository.find_or_create_by(:url => options['url'])
    if options['userid'] && options['password']
      auth = gr.authentications.detect { |item| item.authtype == 'default' }
      if auth
        auth.update_attributes(options.slice(*AUTH_KEYS))
      else
        gr.authentications.create(options.slice(*AUTH_KEYS).merge(:authtype => 'default'))
      end
    end

    gr.refresh
    gr.reload
    options['git_repository_id'] = gr.id

    validate_refs(gr, options)
    import_git_repo(options)
  end

  def self.import_git_repo(options)
    git_repo = GitRepository.find(options['git_repository_id'])
    raise "Git repository with id #{options['git_repository_id']} not found" unless git_repo

    MiqAeDomain.find_by(:name => options['domain']).try(:destroy) if options['domain']
    import_options(git_repo, options)
    domain = Array.wrap(MiqAeImport.new(options['domain'] || '*', options).import).first
    raise MiqAeException::DomainNotFound, "Import of domain failed" unless domain
    domain.update_git_info(git_repo, options['ref'], options['ref_type'])
    domain
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
    when BRANCH
      git_repository.branch_info(ref)
    when TAG
      git_repository.tag_info(ref)
    end
  end

  def display_name
    return self[:display_name] unless git_enabled?
    "#{domain_name} (#{latest_ref_info['name']})"
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

  def about_file_name
    about = about_class
    File.join(MiqAeDatastore::DATASTORE_DIRECTORY, "#{about.fqname}#{CLASS_DIR_SUFFIX}", CLASS_YAML_FILENAME) if about
  end

  def self.import_options(git_repo, options)
    options['git_dir'] = git_repo.directory_name
    options['preview'] ||= false
    options['ref'] ||= DEFAULT_BRANCH
    options['ref_type'] ||= BRANCH
    options['ref_type'] = options['ref_type'].downcase

    case options['ref_type'].downcase
    when BRANCH
      options['branch'] = options['ref']
    when TAG
      options['tag'] = options['ref']
    end
  end

  private_class_method :import_options

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

  def self.validate_refs(repo, options)
    match = nil
    case options['ref_type'].downcase
    when BRANCH
      other_name = "origin/#{options['ref']}"
      match = repo.git_branches.detect { |branch| branch.name.casecmp(options['ref']) == 0 }
      match ||= repo.git_branches.detect { |branch| branch.name.casecmp(other_name) == 0 }
    when TAG
      match = repo.git_tags.detect { |tag| tag.name.casecmp(options['ref']) == 0 }
    end
    unless match
      raise ArgumentError, "#{options['ref_type'].titleize} #{options['ref']} doesn't exist in repository"
    end
    options['ref'] = match.name
  end
  private_class_method :validate_refs
end

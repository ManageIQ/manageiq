class MiqAeDomain < MiqAeNamespace
  default_scope { where(:parent_id => nil).where(arel_table[:name].not_eq("$")) }
  validates_inclusion_of :parent_id, :in => [nil], :message => 'should be nil for Domain'

  validates_presence_of :tenant, :message => "object is needed to own the domain"
  after_destroy :squeeze_priorities
  default_value_for :system,  false
  default_value_for :enabled, false
  before_save :default_priority
  belongs_to :tenant
  belongs_to :git_repository

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

  def default_priority
    self.priority = MiqAeDomain.highest_priority(tenant) + 1 unless priority
  end

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
                       :system         => true)
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

  private

  def squeeze_priorities
    ids = MiqAeDomain.where('priority > 0', :tenant => tenant).order('priority ASC').collect(&:id)
    MiqAeDomain.reset_priority_by_ordered_ids(ids)
  end

  def self.any_enabled?
    MiqAeDomain.enabled.count > 0
  end

  def self.any_unlocked?
    MiqAeDomain.where('system is null OR system = ?', [false]).count > 0
  end

  def self.all_unlocked
    MiqAeDomain.where('system is null OR system = ?', [false]).order('priority DESC')
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

    case options['ref_type']
    when BRANCH
      options['branch'] = options['ref']
    when TAG
      options['tag'] = options['ref']
    end
  end

  private_class_method :import_options
end

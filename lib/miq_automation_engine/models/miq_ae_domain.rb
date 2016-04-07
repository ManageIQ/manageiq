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
  belongs_to :git_repository

  EXPORT_EXCLUDE_KEYS = [/^id$/, /^(?!tenant).*_id$/, /^created_on/, /^updated_on/,
                         /^updated_by/, /^reserved$/, /^commit_message/,
                         /^commit_time/, /^commit_sha/, /^branch/, /^tag$/,
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

  def self.import_git_repo(domain_name, git_repo, branch = nil, tag = nil)
    MiqAeDomain.where(:name => domain_name).first.try(:destroy)
    branch = 'origin/master' if branch.nil? && tag.nil?
    options = {'git_dir' => git_repo.directory_name, 'branch' => branch, 'tag' => tag, 'preview' => false}
    MiqAeImport.new(domain_name, options).import
    domain = MiqAeDomain.where(:name => domain_name).first
    raise MiqAeException::DomainNotFound, "Domain #{domain_name} not found after import" unless domain
    domain.update_git_info(git_repo, branch, tag)
  end

  def update_git_info(git_repo, branch, tag)
    self.branch = branch
    self.git_repository = git_repo
    self.tag = tag
    save
    info = changed_info
    update_attributes!(:last_import_on => Time.now.utc,
                       :commit_sha     => info[:commit_sha],
                       :commit_message => info[:commit_message],
                       :commit_time    => info[:commit_time],
                       :system         => true)
  end

  def git_enabled?
    git_repository.present?
  end

  def git_repo_changed?
    commit_sha != changed_info[:commit_sha]
  end

  def changed_info
    raise MiqAeException::InvalidDomain, "Not GIT enabled" unless git_enabled?
    raise "No branch or tag selected" if branch.nil? && tag.nil?
    info = git_repository.branch_info(branch) if branch
    info ||= git_repository.tag_info(tag) if tag
    info
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

  def about_class
    ns = MiqAeNamespace.where(:parent_id => id).find_by("lower(name) = ?", "system")
    MiqAeClass.where(:namespace_id => ns.id).find_by("lower(name) = ?", "about") if ns
  end

  def about_file_name
    about = about_class
    File.join(MiqAeDatastore::DATASTORE_DIRECTORY, "#{about.fqname}#{CLASS_DIR_SUFFIX}", CLASS_YAML_FILENAME) if about
  end
end

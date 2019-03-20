class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource
  FRIENDLY_NAME = "Ansible Automation Inside Project".freeze
  REPO_DIR      = Rails.root.join("tmp/git_repos")

  validates :name,       :presence => true # TODO: unique within region?
  validates :scm_type,   :presence => true, :inclusion => { :in => %w(git) }
  validates :scm_branch, :presence => true

  default_value_for :scm_type,   "git"
  default_value_for :scm_branch, "master"

  class << self
    delegate :queue, :notify, :to => ManageIQ::Providers::EmbeddedAnsible
  end
  delegate :queue, :notify, :to => :class

  def self.display_name(number = 1)
    n_('Repository (Embedded Ansible)', 'Repositories (Embedded Ansible)', number)
  end

  def self.create_in_provider(manager_id, params)
    error = nil

    params.delete(:scm_type)   if params[:scm_type].blank?
    params.delete(:scm_branch) if params[:scm_branch].blank?

    create!(params.merge(:manager_id => manager_id)).tap do |source|
      source.sync
    end
    # TODO: Should this return the new object since it will be put on the task with a binary blob part?
    #   or should this just put a new item on the queue to do the "refresh"
  rescue => error
    _log.debug error.result.error if error.is_a?(AwesomeSpawn::CommandResultError)
    raise
  ensure
    notify(self, 'creation', manager_id, params, error.nil?)
  end

  def self.create_in_provider_queue(manager_id, params, auth_user = nil)
    manager = parent.find(manager_id)
    action = "Creating #{self::FRIENDLY_NAME} (name=#{params[:name]})"
    queue(self, manager.my_zone, nil, "create_in_provider", [manager_id, params], action, auth_user)
  end

  def update_in_provider(params)
    error = nil
    update_attributes!(params.except(:task_id, :miq_task_id))
    sync
    self
  rescue => error
    raise
  ensure
    notify(self.class, 'update', manager.id, params, error.nil?)
  end

  def update_in_provider_queue(params, auth_user = nil)
    action = "Updating #{self.class::FRIENDLY_NAME}"
    queue(self.class, manager.my_zone, id, "update_in_provider", [params], action, auth_user)
  end

  def delete_in_provider
    error = nil
    destroy!
    remove_clone
    self
  rescue => error
    raise
  ensure
    notify(self.class, 'deletion', manager.id, {:manager_ref => manager_ref}, error.nil?)
  end

  def delete_in_provider_queue(auth_user = nil)
    action = "Deleting #{self.class::FRIENDLY_NAME}"
    queue(self.class, manager.my_zone, id, "delete_in_provider", [], action, auth_user)
  end

  def sync
    ensure_clone
  end

  private

  def git(*params, chdir: true)
    args = {:params => params, :chdir => repo_dir}
    args.delete(:chdir) unless chdir
    AwesomeSpawn.run!("git", args).tap do |result|
      _log.debug result.output
    end
  end

  def ensure_clone
    _log.info "Ensuring presence of git repo #{scm_url.inspect}..."

    if !repo_dir.exist?
      _log.info "Cloning git repo #{scm_url.inspect}..."
      git("clone", scm_url, repo_dir, :chdir => false)
    else
      _log.info "Fetching latest from #{scm_url.inspect}..."
      git("remote", "set-url", "origin", scm_url) # In case the url has changed
      git("fetch")
    end

    _log.info "Checking out #{scm_branch.inspect}..."
    git("checkout", scm_branch)
    git("reset", :hard, "origin/#{scm_branch}")

    _log.info "Ensuring presence of git repo #{scm_url.inspect}...Complete"
  end

  def remove_clone
    repo_dir = repo_dir.to_s
    _log.info "Ensuring removal of git repo located at #{repo_dir.inspect}..."
    raise ArgumentError, "invalid repo dir #{repo_dir.inspect}" unless repo_dir.start_with?(REPO_DIR.to_s)
    FileUtils.rm_rf(repo_dir)
    _log.info "Ensuring removal of git repo located at #{repo_dir.inspect}...Complete"
  end

  def repo_dir
    @repo_dir ||= REPO_DIR.join(id.to_s)
  end
end

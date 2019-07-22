class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource
  FRIENDLY_NAME = "Ansible Automation Inside Project".freeze
  REPO_DIR      = Rails.root.join("tmp", "git_repos")

  validates :name,       :presence => true # TODO: unique within region?
  validates :scm_type,   :presence => true, :inclusion => { :in => %w[git] }
  validates :scm_branch, :presence => true

  default_value_for :scm_type,   "git"
  default_value_for :scm_branch, "master"

  include ManageIQ::Providers::EmbeddedAnsible::CrudCommon

  def self.display_name(number = 1)
    n_('Repository (Embedded Ansible)', 'Repositories (Embedded Ansible)', number)
  end

  def self.notify_on_provider_interaction?
    true
  end

  def self.raw_create_in_provider(manager, params)
    params.delete(:scm_type)   if params[:scm_type].blank?
    params.delete(:scm_branch) if params[:scm_branch].blank?

    transaction { create!(params.merge(:manager => manager)).tap(&:sync) }
  end

  def raw_update_in_provider(params)
    transaction do
      update_attributes!(params.except(:task_id, :miq_task_id))
      sync
    end
  end

  def raw_delete_in_provider
    transaction do
      destroy!
      remove_clone
    end
  end

  def sync
    ensure_clone
    sync_playbooks
  end

  def sync_queue(auth_user = nil)
    queue("sync", [], "Synchronizing", auth_user)
  end

  def path_to_playbook(playbook_name)
    repo_dir.join(playbook_name)
  end

  private

  def git(*params, chdir: true)
    args = {:params => params, :chdir => repo_dir}
    args.delete(:chdir) unless chdir
    AwesomeSpawn.run!("git", args).tap do |result|
      _log.debug(result.output)
    end
  end

  def ensure_clone
    _log.info("Ensuring presence of git repo #{scm_url.inspect}...")

    if !repo_dir.exist?
      _log.info("Cloning git repo #{scm_url.inspect}...")
      git("clone", scm_url, repo_dir, :chdir => false)
    else
      _log.info("Fetching latest from #{scm_url.inspect}...")
      git("remote", "set-url", "origin", scm_url) # In case the url has changed
      git("fetch")
    end

    _log.info("Checking out #{scm_branch.inspect}...")
    git("checkout", scm_branch)
    git("reset", :hard, "origin/#{scm_branch}")

    _log.info("Ensuring presence of git repo #{scm_url.inspect}...Complete")
  end

  def remove_clone
    return unless repo_dir.exist?

    dir = repo_dir.to_s
    _log.info("Ensuring removal of git repo located at #{dir.inspect}...")
    raise ArgumentError, "invalid repo dir #{dir.inspect}" unless dir.start_with?(REPO_DIR.to_s)

    FileUtils.rm_rf(dir)
    _log.info("Ensuring removal of git repo located at #{dir.inspect}...Complete")
  end

  def sync_playbooks
    transaction do
      current = configuration_script_payloads.index_by(&:name)

      playbooks_in_repo_dir.each do |e|
        found = current.delete(e[:name]) || self.class.parent::Playbook.new(:configuration_script_source_id => id)
        found.update_attributes!(e)
      end

      current.values.each(&:destroy)

      configuration_script_payloads.reload
    end
    true
  end

  def playbooks_in_repo_dir
    Dir.glob(repo_dir.join("*.y{a,}ml")).collect do |file|
      name = File.basename(file)
      description = begin
                      YAML.safe_load(File.read(file)).fetch_path(0, "name")
                    rescue StandardError
                      nil
                    end
      {:name => name, :description => description, :manager_id => manager_id}
    end
  end

  def repo_dir
    @repo_dir ||= REPO_DIR.join(id.to_s)
  end
end

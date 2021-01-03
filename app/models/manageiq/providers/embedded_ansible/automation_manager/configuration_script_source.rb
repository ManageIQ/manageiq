class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource
  FRIENDLY_NAME = "Embedded Ansible Project".freeze

  validates :name,       :presence => true # TODO: unique within region?
  validates :scm_type,   :presence => true, :inclusion => { :in => %w[git] }
  validates :scm_branch, :presence => true

  default_value_for :scm_type,   "git"
  default_value_for :scm_branch, "master"

  belongs_to :git_repository, :autosave => true, :dependent => :destroy
  before_validation :sync_git_repository

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

    transaction { create!(params.merge(:manager => manager, :status => "new")) }
  end

  def self.create_in_provider(manager_id, params)
    super.tap(&:sync_and_notify)
  end

  def raw_update_in_provider(params)
    transaction do
      update!(params.except(:task_id, :miq_task_id))
    end
  end

  def update_in_provider(params)
    super.tap(&:sync_and_notify)
  end

  def raw_delete_in_provider
    destroy!
  end

  def git_repository
    (super || (ensure_git_repository && super)).tap { |r| sync_git_repository(r) }
  end

  private def ensure_git_repository
    transaction do
      repo = GitRepository.create!(attrs_for_sync_git_repository)
      if new_record?
        self.git_repository_id = repo.id
      elsif !update_columns(:git_repository_id => repo.id) # rubocop:disable Rails/SkipsModelValidations
        raise ActiveRecord::RecordInvalid, "git_repository_id could not be set"
      end
    end
    true
  end

  private def sync_git_repository(git_repository = nil)
    return unless name_changed? || scm_url_changed? || authentication_id_changed?

    git_repository ||= self.git_repository
    git_repository.attributes = attrs_for_sync_git_repository
  end

  private def attrs_for_sync_git_repository
    {
      :name              => name,
      :url               => scm_url,
      :authentication_id => authentication_id,
      :verify_ssl        => OpenSSL::SSL::VERIFY_NONE
    }
  end

  def sync
    update!(:status => "running")
    transaction do
      current = configuration_script_payloads.index_by(&:name)

      playbooks_in_git_repository.each do |f|
        found = current.delete(f) || self.class.parent::Playbook.new(:configuration_script_source_id => id)
        found.update!(:name => f, :manager_id => manager_id)
      end

      current.values.each(&:destroy)

      configuration_script_payloads.reload
    end
    update!(:status            => "successful",
            :last_updated_on   => Time.zone.now,
            :last_update_error => nil)
  rescue => error
    update!(:status            => "error",
            :last_updated_on   => Time.zone.now,
            :last_update_error => format_sync_error(error))
    raise error
  end

  def sync_and_notify
    notify("syncing") { sync }
  end

  def sync_queue(auth_user = nil)
    queue("sync", [], "Synchronizing", auth_user)
  end

  def playbooks_in_git_repository
    git_repository.update_repo
    git_repository.with_worktree do |worktree|
      worktree.ref = scm_branch
      worktree.blob_list.select do |filename|
        playbook_dir?(filename) && playbook?(filename, worktree)
      end
    end
  end

  def checkout_git_repository(target_directory)
    git_repository.update_repo
    git_repository.checkout(scm_branch, target_directory)
  end

  ERROR_MAX_SIZE = 50.kilobytes
  def format_sync_error(error)
    result = error.message.dup
    result << "\n\n"
    result << error.backtrace.join("\n")
    result.mb_chars.limit(ERROR_MAX_SIZE)
  end

  private

  VALID_PLAYBOOK_CHECK = /^\s*?-?\s*?(?:hosts|include|import_playbook):\s*?.*?$/.freeze

  # Confirms two things:
  #
  #   - The file extension is a yaml extension
  #   - The content of the file is "a playbook"
  #
  # A file is considered a playbook if it has one line that matches
  # VALID_PLAYBOOK_CHECK, or it starts with $ANSIBLE_VAULT, which in that case
  # it is an encrypted file which it isn't possible to discern if it is a
  # playbook or a different type of yaml file.
  #
  def playbook?(filename, worktree)
    return false unless filename.match?(/\.ya?ml$/)

    content = worktree.read_file(filename)
    return true if content.start_with?("$ANSIBLE_VAULT")

    content.each_line do |line|
      return true if line.match?(VALID_PLAYBOOK_CHECK)
    end

    false
  end

  INVALID_DIRS = %w[roles tasks group_vars host_vars].freeze

  # Given a Pathname, determine if it includes invalid directories so it can be
  # removed from consideration, and also ignore hidden files and directories.
  def playbook_dir?(filepath)
    elements = Pathname.new(filepath).each_filename.to_a

    elements.none? { |el| el.starts_with?('.') || INVALID_DIRS.include?(el) }
  end
end

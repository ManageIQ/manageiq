class ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource < ManageIQ::Providers::AutomationManager::ConfigurationScriptSource
  include ManageIQ::Providers::EmbeddedAutomationManager::CrudCommon

  supports :create
  supports :update
  supports :delete

  virtual_attribute :verify_ssl, :integer

  validates :name,       :presence => true # TODO: unique within region?
  validates :scm_type,   :presence => true, :inclusion => {:in => %w[git]}
  validates :scm_branch, :presence => true

  default_value_for :scm_type,   "git"
  default_value_for :scm_branch, "master"

  belongs_to :git_repository, :autosave => true, :dependent => :destroy
  before_validation :sync_git_repository

  def self.display_name(number = 1)
    n_('Repository', 'Repositories', number)
  end

  def self.create_in_provider(manager_id, params)
    super.tap(&:sync_and_notify)
  end

  def self.raw_create_in_provider(manager, params)
    params.delete(:scm_type)   if params[:scm_type].blank?
    params.delete(:scm_branch) if params[:scm_branch].blank?

    transaction { create!(params.merge(:manager => manager, :status => "new")) }
  end

  def update_in_provider(params)
    super.tap(&:sync_and_notify)
  end

  def raw_update_in_provider(params)
    transaction do
      update!(params.except(:task_id, :miq_task_id))
    end
  end

  def raw_delete_in_provider
    destroy!
  end

  def sync_and_notify
    notify("syncing") { sync }
  end

  def git_repository
    (super || (ensure_git_repository && super))&.tap { |r| sync_git_repository(r) }
  end

  def verify_ssl=(val)
    @verify_ssl = case val
                  when 0, false then OpenSSL::SSL::VERIFY_NONE
                  when 1, true  then OpenSSL::SSL::VERIFY_PEER
                  else
                    OpenSSL::SSL::VERIFY_NONE
                  end

    if git_repository_id && git_repository.verify_ssl != @verify_ssl
      @verify_ssl_changed = true
    end
  end

  def verify_ssl
    if @verify_ssl
      @verify_ssl
    elsif git_repository_id
      git_repository.verify_ssl
    else
      @verify_ssl ||= OpenSSL::SSL::VERIFY_NONE
    end
  end

  def sync_queue(auth_user = nil)
    queue("sync", [], "Synchronizing", auth_user)
  end

  def sync
    raise NotImplementedError, N_("sync must be implemented in a subclass")
  end

  def checkout_git_repository(target_directory)
    return if git_repository.nil?

    git_repository.update_repo
    git_repository.checkout(scm_branch, target_directory)
  end

  private

  def ensure_git_repository
    return if scm_url.blank?

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

  def sync_git_repository(git_repository = nil)
    return unless name_changed? || scm_url_changed? || authentication_id_changed? || @verify_ssl_changed

    git_repository ||= self.git_repository
    return if git_repository.nil?

    git_repository.attributes = attrs_for_sync_git_repository
  end

  def attrs_for_sync_git_repository
    {
      :name              => name,
      :url               => scm_url,
      :authentication_id => authentication_id,
      :verify_ssl        => verify_ssl
    }
  end
end

class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource
  FRIENDLY_NAME = "Embedded Ansible Project".freeze

  validates :name,       :presence => true # TODO: unique within region?
  validates :scm_type,   :presence => true, :inclusion => { :in => %w[git] }
  validates :scm_branch, :presence => true

  default_value_for :scm_type,   "git"
  default_value_for :scm_branch, "master"

  belongs_to :git_repository, :dependent => :destroy

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
      update_attributes!(params.except(:task_id, :miq_task_id))
    end
  end

  def update_in_provider(params)
    super.tap(&:sync_and_notify)
  end

  def raw_delete_in_provider
    destroy!
  end

  def git_repository
    super || begin
      transaction do
        update!(:git_repository => GitRepository.create!(:url => scm_url))
      end
      super
    end
  end

  def sync
    update_attributes!(:status => "running")
    transaction do
      current = configuration_script_payloads.index_by(&:name)

      playbooks_in_git_repository.each do |f|
        found = current.delete(f) || self.class.parent::Playbook.new(:configuration_script_source_id => id)
        found.update_attributes!(:name => f, :manager_id => manager_id)
      end

      current.values.each(&:destroy)

      configuration_script_payloads.reload
    end
    update_attributes!(:status            => "successful",
                       :last_updated_on   => Time.zone.now,
                       :last_update_error => nil)
  rescue => error
    update_attributes!(:status            => "error",
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
    git_repository.entries(scm_branch, "").grep(/\.ya?ml$/)
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
end

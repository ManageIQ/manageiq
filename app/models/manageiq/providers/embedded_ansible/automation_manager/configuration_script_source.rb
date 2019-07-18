class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource
  FRIENDLY_NAME = "Ansible Automation Inside Project".freeze
  REPO_DIR      = Rails.root.join("tmp", "git_repos")

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

    transaction { create!(params.merge(:manager => manager)).tap(&:sync) }
  end

  def raw_update_in_provider(params)
    transaction do
      update_attributes!(params.except(:task_id, :miq_task_id))
      sync
    end
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
    transaction do
      current = configuration_script_payloads.index_by(&:name)

      playbooks_in_git_repository.each do |f|
        found = current.delete(f) || self.class.parent::Playbook.new(:configuration_script_source_id => id)
        found.update_attributes!(:name => f, :manager_id => manager_id)
      end

      current.values.each(&:destroy)

      configuration_script_payloads.reload
    end
    true
  end

  def sync_queue(auth_user = nil)
    queue("sync", [], "Synchronizing", auth_user)
  end

  def path_to_playbook(playbook_name)
    repo_dir.join(playbook_name)
  end

  private

  def playbooks_in_git_repository
    git_repository.entries("").grep(/\.ya?ml$/)
  end

  def repo_dir
    @repo_dir ||= REPO_DIR.join(id.to_s)
  end
end

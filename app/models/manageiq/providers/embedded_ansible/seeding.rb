module ManageIQ::Providers::EmbeddedAnsible::Seeding
  extend ActiveSupport::Concern

  module ClassMethods
    def seed
      provider = ManageIQ::Providers::EmbeddedAnsible::Provider.in_my_region.first_or_initialize
      provider.update!(
        :name => "Embedded Ansible"
      )

      manager = provider.automation_manager
      manager.update!(
        :name => "Embedded Ansible",
        :zone => MiqServer.my_server.zone # TODO: Do we even need zone?
      )

      ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential.find_or_create_by!(
        :name     => "#{Vmdb::Appliance.PRODUCT_NAME} Default Credential",
        :resource => manager
      )

      create_local_playbook_repo
      local_repo = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource.find_or_create_by!(
        :name       => "#{Vmdb::Appliance.PRODUCT_NAME} Default Project",
        :manager_id => manager.id
      )
      local_repo.raw_update_in_provider(
        :scm_type             => "git",
        :scm_url              => "file://#{local_playbook_repo_dir}",
        :scm_update_on_launch => false
      )
    end

    private

    def create_local_playbook_repo
      Ansible::Content.consolidate_plugin_playbooks

      Dir.chdir(local_playbook_repo_dir) do
        require 'rugged'
        repo = Rugged::Repository.init_at(".")
        index = repo.index
        index.add_all("*")
        index.write

        options              = {}
        options[:tree]       = index.write_tree(repo)
        options[:author]     = options[:committer] = { :email => "system@localhost", :name => "System", :time => Time.now.utc }
        options[:message]    = "Initial Commit"
        options[:parents]    = []
        options[:update_ref] = 'HEAD'
        Rugged::Commit.create(repo, options)
      end
    end

    def local_playbook_repo_dir
      Ansible::Content::PLUGIN_CONTENT_DIR
    end
  end
end

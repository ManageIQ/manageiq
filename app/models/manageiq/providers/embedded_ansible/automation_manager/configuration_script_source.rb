class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource
  FRIENDLY_NAME = "Embedded Ansible Project".freeze

  def self.display_name(number = 1)
    n_('Repository (Embedded Ansible)', 'Repositories (Embedded Ansible)', number)
  end

  def self.notify_on_provider_interaction?
    true
  end

  def sync
    super do |worktree|
      playbooks_in_git_repository = worktree.blob_list.select do |filename|
        playbook_dir?(filename) && playbook?(filename, worktree)
      end

      playbooks_in_git_repository.map do |f|
        configuration_script_payloads
          .create_with(:type => self.class.module_parent::Playbook.name, :manager_id => manager_id)
          .find_or_create_by(:name => f)
      end
    end
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
  def playbook?(filename, content)
    return false unless filename.match?(/\.ya?ml$/)
    return true if encrypted_playbook?(content)

    content.each_line do |line|
      return true if line.match?(VALID_PLAYBOOK_CHECK)
    end

    false
  end

  INVALID_DIRS = %w[roles tasks group_vars host_vars].freeze

  # Check for an encrypted playbook
  def encrypted_playbook?(content)
    content.start_with?("$ANSIBLE_VAULT")
  end

  # Given a Pathname, determine if it includes invalid directories so it can be
  # removed from consideration, and also ignore hidden files and directories.
  def playbook_dir?(filepath)
    elements = Pathname.new(filepath).each_filename.to_a

    elements.none? { |el| el.starts_with?('.') || INVALID_DIRS.include?(el) }
  end
end

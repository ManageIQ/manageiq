class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource
  FRIENDLY_NAME = "Embedded Ansible Project".freeze

  def self.display_name(number = 1)
    n_('Repository (Embedded Ansible)', 'Repositories (Embedded Ansible)', number)
  end

  def self.notify_on_provider_interaction?
    true
  end

  private_class_method def self.queue_role
    "embedded_ansible"
  end

  def sync
    update!(:status => "running")
    transaction do
      current = configuration_script_payloads.index_by(&:name)

      git_repository.update_repo
      git_repository.with_worktree do |worktree|
        worktree.ref = scm_branch
        worktree.blob_list.each do |filename|
          next unless playbook_dir?(filename)

          content = worktree.read_file(filename)
          next unless playbook?(filename, content)

          found = current.delete(filename) || self.class.module_parent::Playbook.new(:configuration_script_source_id => id)

          attrs = {:name => filename, :manager_id => manager_id}
          unless encrypted_playbook?(content)
            attrs[:payload]      = content
            attrs[:payload_type] = "yaml"
          end

          found.update!(attrs)
        end
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

  def playbooks_in_git_repository
    git_repository.update_repo
    git_repository.with_worktree do |worktree|
      worktree.ref = scm_branch
      worktree.blob_list.select do |filename|
        playbook_dir?(filename) && playbook?(filename, worktree)
      end
    end
  end

  ERROR_MAX_SIZE = 50.kilobytes
  def format_sync_error(error)
    result = error.message.dup
    result << "\n\n"
    result << error.backtrace.join("\n")
    result.mb_chars.limit(ERROR_MAX_SIZE)
  end

  private

  VALID_PLAYBOOK_CHECK = /^\s*?-?\s*?(?:hosts|include|import_playbook):\s*?.*?$/

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

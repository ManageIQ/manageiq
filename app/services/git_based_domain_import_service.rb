class GitBasedDomainImportService
  def queue_import(git_repo_id, branch_or_tag, tenant_id)
    git_repo = GitRepository.find_by(:id => git_repo_id)

    ref_type = if git_repo.git_branches.any? { |git_branch| git_branch.name == branch_or_tag }
                 "branch"
               else
                 "tag"
               end

    import_options = {
      "git_repository_id" => git_repo.id,
      "ref"               => branch_or_tag,
      "ref_type"          => ref_type,
      "tenant_id"         => tenant_id,
      "overwrite"         => true
    }

    task_options = {
      :action => "Import git repository",
      :userid => User.current_user.userid
    }

    queue_options = {
      :class_name  => "MiqAeDomain",
      :method_name => "import_git_repo",
      :role        => "git_owner",
      :args        => [import_options]
    }

    MiqTask.generic_action_with_callback(task_options, queue_options)
  end

  def queue_refresh(git_repo_id)
    task_options = {
      :action => "Refresh git repository",
      :userid => User.current_user.userid
    }

    queue_options = {
      :class_name  => "GitRepository",
      :method_name => "refresh",
      :instance_id => git_repo_id,
      :role        => "git_owner",
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_options, queue_options)
  end

  def queue_refresh_and_import(git_url, ref, ref_type, tenant_id)
    import_options = {
      "git_url"   => git_url,
      "ref"       => ref,
      "ref_type"  => ref_type,
      "tenant_id" => tenant_id,
      "overwrite" => true
    }

    task_options = {
      :action => "Refresh and import git repository",
      :userid => User.current_user.userid
    }

    queue_options = {
      :class_name  => "MiqAeDomain",
      :method_name => "import_git_url",
      :role        => "git_owner",
      :args        => [import_options]
    }

    MiqTask.generic_action_with_callback(task_options, queue_options)
  end

  def import(git_repo_id, branch_or_tag, tenant_id)
    task_id = queue_import(git_repo_id, branch_or_tag, tenant_id)
    task = MiqTask.wait_for_taskid(task_id)

    domain = task.task_results
    raise MiqException::Error, "Domain object not available from task results" unless domain.kind_of?(MiqAeDomain)
    domain.update_attribute(:enabled, true)
  end

  def refresh(git_repo_id)
    task_id = queue_refresh(git_repo_id)
    MiqTask.wait_for_taskid(task_id)

    task = MiqTask.find(task_id)
    raise MiqException::Error, task.message unless task.status == "Ok"

    task.task_results
  end

  def self.available?
    MiqRegion.my_region.role_active?("git_owner")
  end
end

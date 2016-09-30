class GitBasedDomainImportService
  def import(git_repo_id, branch_or_tag, tenant_id)
    git_repo = GitRepository.find_by(:id => git_repo_id)

    ref_type = if git_repo.git_branches.any? { |git_branch| git_branch.name == branch_or_tag }
                 "branch"
               else
                 "tag"
               end

    options = {
      "git_repository_id" => git_repo.id,
      "ref"               => branch_or_tag,
      "ref_type"          => ref_type,
      "tenant_id"         => tenant_id
    }
    domain = MiqAeDomain.import_git_repo(options)
    domain.update_attribute(:enabled, true)
  end

  def self.available?
    MiqRegion.my_region.role_active?("git_owner")
  end
end

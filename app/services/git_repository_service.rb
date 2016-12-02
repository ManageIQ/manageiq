class GitRepositoryService
  def setup(git_url, git_username, git_password, verify_ssl)
    new_git_repo = false
    git_repo = GitRepository.find_or_create_by!(:url => git_url) { new_git_repo = true }
    git_repo.update_attributes(
      :verify_ssl => verify_ssl == "true" ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
    )

    if git_username && git_password
      git_repo.update_authentication(:values => {:userid => git_username, :password => git_password})
    end

    return {:git_repo_id => git_repo.id, :new_git_repo? => new_git_repo}
  end
end

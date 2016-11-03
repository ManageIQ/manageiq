class MiqAeGitImport
  AUTH_KEYS = %w(userid password).freeze
  BRANCH = 'branch'.freeze
  TAG    = 'tag'.freeze
  DEFAULT_BRANCH = 'origin/master'.freeze

  def initialize(options)
    @options = options
    @preview = options['preview']
  end

  def import
    pre_import
    @options['git_dir'] = @git_repo.directory_name
    MiqAeDomain.find_by(:name => @options['domain']).try(:destroy) if @options['domain'] && !@preview
    result = MiqAeYamlImportGitfs.new(@options['domain'] || '*', @options).import
    domain = Array.wrap(result).first
    post_import(domain) unless @preview
    domain
  end

  private

  def pre_import
    repo_from_id if @options['git_repository_id']
    create_repo unless @git_repo
    default_import_options
    validate_refs
    branch_or_tag
  end

  def post_import(domain)
    if domain
      domain.update_git_info(@git_repo, @options['ref'], @options['ref_type'])
    else
      raise MiqAeException::DomainNotFound, "Import of domain failed"
    end
  end

  def repo_from_id
    @git_repo = GitRepository.find(@options['git_repository_id'])
    raise "Git repository with id #{@options['git_repository_id']} not found" unless @git_repo
  end

  def create_repo
    @git_repo = GitRepository.find_or_create_by(:url => @options['git_url'])
    @git_repo.update_attributes(:verify_ssl => @options['verify_ssl'] || OpenSSL::SSL::VERIFY_PEER)
    if @options['userid'] && @options['password']
      @git_repo.update_authentication(:default => @options.slice(*AUTH_KEYS).symbolize_keys)
    end
    @git_repo.refresh
  end

  def default_import_options
    @options['ref'] ||= DEFAULT_BRANCH
    @options['ref_type'] ||= BRANCH
    @options['ref_type'] = @options['ref_type'].downcase
  end

  def branch_or_tag
    case @options['ref_type']
    when BRANCH
      @options['branch'] = @options['ref']
    when TAG
      @options['tag'] = @options['ref']
    else
      raise ArgumentError, "Invalid reference type #{@options['ref_type']} should be branch or tag"
    end
  end

  def validate_refs
    match = nil
    case @options['ref_type']
    when BRANCH
      other_name = "origin/#{@options['ref']}"
      match = @git_repo.git_branches.detect { |branch| branch.name.casecmp(@options['ref']) == 0 }
      match ||= @git_repo.git_branches.detect { |branch| branch.name.casecmp(other_name) == 0 }
    when TAG
      match = @git_repo.git_tags.detect { |tag| tag.name.casecmp(@options['ref']) == 0 }
    end
    unless match
      raise ArgumentError, "#{@options['ref_type'].titleize} #{@options['ref']} doesn't exist in repository"
    end
    @options['ref'] = match.name
  end
end

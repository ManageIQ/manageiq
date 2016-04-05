class GitRepository < ApplicationRecord
  include AuthenticationMixin
  serialize :branches
  serialize :tags
  validates :url, :format => URI::regexp(%w(http https)), :allow_nil => false
  before_save :default_values

  def refresh
    @repo = Dir.exist?(dirname) ? update_repo : init_repo
    self.branches = @repo.branches(:remote)
    self.tags = @repo.tags
    self.last_refresh_on = Time.now.utc
    save!
  end

  def branch_info(name)
    refresh unless @repo
    @repo.branch_info(name)
  end

  def tag_info(name)
    refresh unless @repo
    @repo.tag_info(name)
  end

  private

  def init_repo
    repo_block do
      params = {:clone => true, :url => url, :path => dirname}
      params[:ssl_no_verify] = verify_ssl.nil? || verify_ssl == 0
      if authentications.any?
        params[:username] = authentications.first.userid
        params[:password] = authentications.first.password
      end
      GitWorktree.new(params)
    end
  end

  def update_repo
    repo_block do
      GitWorktree.new(:path => dirname).tap do |repo|
        repo.send(:fetch_and_merge)
      end
    end
  end

  def repo_block
    yield
  rescue ::Rugged::NetworkError => err
    raise MiqException::MiqUnreachableError, err.message
  rescue => err
    raise MiqException::Error, err.message
  end

  def default_values
    self.dirname ||= default_dir_name
    self.verify_ssl ||= 1
  end

  def default_dir_name
    parsed = URI.parse(url)
    raise "Invalid URL missing path" if parsed.path.blank?
    File.join(MiqAeDatastore::GIT_REPO_DIRECTORY, parsed.path)
  end
end

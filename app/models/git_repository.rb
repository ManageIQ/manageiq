class GitRepository < ApplicationRecord
  include AuthenticationMixin
  validates :url, :format => URI::regexp(%w(http https)), :allow_nil => false
  before_save :default_values
  has_many :git_branches, :dependent => :destroy
  has_many :git_tags, :dependent => :destroy
  VALID_KEYS = %w(commit_sha commit_message commit_time).freeze

  def refresh
    @repo = Dir.exist?(dirname) ? update_repo : init_repo
    refresh_branches
    refresh_tags
    self.last_refresh_on = Time.now.utc
    save!
  end

  def branch_info(name)
    refresh unless @repo
    branch = git_branches.detect { |item| item.name == name }
    raise "Branch #{name} not found" unless branch
    branch.attributes.slice(*VALID_KEYS)
  end

  def tag_info(name)
    refresh unless @repo
    tag = git_tags.detect { |item| item.name == name }
    raise "GIT Tag #{name} not found" unless tag
    tag.attributes.slice(*VALID_KEYS)
  end

  private

  def refresh_branches
    current_branches = git_branches
    @repo.branches(:remote).each do |branch|
      stored_branch = current_branches.detect { |item| item.name == branch }
      hash = @repo.branch_info(branch)
      attrs = {:name           => branch,
               :commit_sha     => hash[:commit_sha],
               :commit_time    => hash[:time],
               :commit_message => hash[:message]}
      stored_branch ? stored_branch.update_attributes(attrs) : git_branches.create!(attrs)
    end
  end

  def refresh_tags
    current_tags = git_tags
    @repo.tags.each do |tag|
      stored_tag = current_tags.detect { |item| item.name == tag }
      hash = @repo.tag_info(tag)
      attrs = {:name           => tag,
               :commit_sha     => hash[:commit_sha],
               :commit_time    => hash[:time],
               :commit_message => hash[:message]}
      stored_tag ? stored_tag.update_attributes(attrs) : git_tags.create!(attrs)
    end
  end

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

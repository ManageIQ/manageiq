class GitRepository < ApplicationRecord
  include AuthenticationMixin

  GIT_REPO_DIRECTORY = Rails.root.join('data/git_repos')

  validates :url, :format => URI::regexp(%w(http https)), :allow_nil => false
  validate  :check_path

  default_value_for :verify_ssl, OpenSSL::SSL::VERIFY_PEER
  validates :verify_ssl, :inclusion => {:in => [OpenSSL::SSL::VERIFY_NONE, OpenSSL::SSL::VERIFY_PEER]}

  has_many :git_branches, :dependent => :destroy
  has_many :git_tags, :dependent => :destroy
  after_destroy :delete_repo_dir

  INFO_KEYS = %w(commit_sha commit_message commit_time name).freeze

  def refresh
    ensure_repo
    transaction do
      refresh_branches
      refresh_tags
      self.last_refresh_on = Time.now.utc
      save!
    end
  end

  def branch_info(name)
    refresh unless repo
    branch = git_branches.detect { |item| item.name == name }
    raise "Branch #{name} not found" unless branch
    branch.attributes.slice(*INFO_KEYS)
  end

  def tag_info(name)
    refresh unless repo
    tag = git_tags.detect { |item| item.name == name }
    raise "Tag #{name} not found" unless tag
    tag.attributes.slice(*INFO_KEYS)
  end

  def directory_name
    parsed = URI.parse(url)
    raise "Invalid URL missing path" if parsed.path.blank?
    File.join(GIT_REPO_DIRECTORY, parsed.path)
  end

  def self_signed_cert_cb(_valid, _host)
    true
  end

  private

  attr_reader :repo

  def refresh_branches
    current_branches = git_branches.index_by(&:name)
    repo.branches(:remote).each do |branch|
      info = repo.branch_info(branch)
      attrs = {:name           => branch,
               :commit_sha     => info[:commit_sha],
               :commit_time    => info[:time],
               :commit_message => info[:message]}

      stored_branch = current_branches.delete(branch)
      stored_branch ? stored_branch.update_attributes!(attrs) : git_branches.create!(attrs)
    end
    git_branches.delete(current_branches.values)
  end

  def refresh_tags
    current_tags = git_tags.index_by(&:name)
    repo.tags.each do |tag|
      info = repo.tag_info(tag)
      attrs = {:name           => tag,
               :commit_sha     => info[:commit_sha],
               :commit_time    => info[:time],
               :commit_message => info[:message]}

      stored_tag = current_tags.delete(tag)
      stored_tag ? stored_tag.update_attributes(attrs) : git_tags.create!(attrs)
    end
    git_tags.delete(current_tags.values)
  end

  def ensure_repo
    @repo = Dir.exist?(directory_name) ? update_repo : init_repo
  end

  def init_repo
    repo_block do
      params = {:clone => true, :url => url}.merge(repo_params)
      GitWorktree.new(params)
    end
  end

  def update_repo
    repo_block do
      GitWorktree.new(repo_params).tap do |repo|
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

  def repo_params
    params = {:path => directory_name}
    params[:certificate_check] = method(:self_signed_cert_cb) if verify_ssl == OpenSSL::SSL::VERIFY_NONE
    if authentications.any?
      params[:username] = default_authentication.userid
      params[:password] = default_authentication.password
    end
    params
  end

  def delete_repo_dir
    FileUtils.rm_rf(directory_name)
  end

  def check_path
    return unless url
    parsed = URI.parse(url)
    errors.add(:url, "missing path component e.g. https://www.example.com/path") if parsed.path.blank?
  end
end

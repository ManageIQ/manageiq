class GitRepository < ApplicationRecord
  include AuthenticationMixin

  validates :url, :format => URI::regexp(%w(http https)), :allow_nil => false

  default_value_for :verify_ssl, OpenSSL::SSL::VERIFY_PEER
  validates :verify_ssl, :inclusion => {:in => [OpenSSL::SSL::VERIFY_NONE, OpenSSL::SSL::VERIFY_PEER]}

  has_many :git_branches, :dependent => :destroy
  has_many :git_tags, :dependent => :destroy
  after_destroy :delete_repo_dir

  INFO_KEYS = %w(commit_sha commit_message commit_time name).freeze

  def refresh
    @repo = Dir.exist?(directory_name) ? update_repo : init_repo
    refresh_branches
    refresh_tags
    self.last_refresh_on = Time.now.utc
    save!
  end

  def branch_info(name)
    refresh unless @repo
    branch = git_branches.detect { |item| item.name == name }
    raise "Branch #{name} not found" unless branch
    branch.attributes.slice(*INFO_KEYS)
  end

  def tag_info(name)
    refresh unless @repo
    tag = git_tags.detect { |item| item.name == name }
    raise "GIT Tag #{name} not found" unless tag
    tag.attributes.slice(*INFO_KEYS)
  end

  def directory_name
    parsed = URI.parse(url)
    raise "Invalid URL missing path" if parsed.path.blank?
    File.join(MiqAeDatastore::GIT_REPO_DIRECTORY, parsed.path)
  end

  def self_signed_cert_cb(_valid, _host)
    true
  end

  private

  def refresh_branches
    current_branches = git_branches.to_a
    @repo.branches(:remote).each do |branch|
      stored_branch = current_branches.detect { |item| item.name == branch }
      hash = @repo.branch_info(branch)
      attrs = {:name           => branch,
               :commit_sha     => hash[:commit_sha],
               :commit_time    => hash[:time],
               :commit_message => hash[:message]}
      stored_branch ? stored_branch.update_attributes(attrs) : git_branches.create!(attrs)
      current_branches.delete(stored_branch) if stored_branch
    end
    git_branches.delete(current_branches)
  end

  def refresh_tags
    current_tags = git_tags.to_a
    @repo.tags.each do |tag|
      stored_tag = current_tags.detect { |item| item.name == tag }
      hash = @repo.tag_info(tag)
      attrs = {:name           => tag,
               :commit_sha     => hash[:commit_sha],
               :commit_time    => hash[:time],
               :commit_message => hash[:message]}
      stored_tag ? stored_tag.update_attributes(attrs) : git_tags.create!(attrs)
      current_tags.delete(stored_tag) if stored_tag
    end
    git_tags.delete(current_tags)
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
      params[:username] = authentications.first.userid
      params[:password] = authentications.first.password
    end
    params
  end

  def delete_repo_dir
    FileUtils.rm_rf(directory_name)
  end
end

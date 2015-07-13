require 'uri'
require 'mount/miq_generic_mount_session'

module FileDepotMixin
  extend ActiveSupport::Concern
  SUPPORTED_DEPOTS = {
    'smb' => 'Samba',
    'nfs' => 'Network File System'
  }.freeze

  included do
    include AuthenticationMixin
    before_save :verify_uri_prefix_before_save
  end

  module ClassMethods
    def verify_depot_settings(settings)
      return true unless MiqEnvironment::Command.is_appliance?

      res = self.mnt_instance(settings).verify
      raise "Connection Settings validation failed with error: #{res.last}" unless res.first
      res
    end

    def mnt_instance(settings)
      settings[:uri_prefix] ||= self.get_uri_prefix(settings[:uri])
      klass = "Miq#{settings[:uri_prefix].capitalize}Session".constantize
      klass.new(settings)
    end

    def get_uri_prefix(uri_str)
      return nil if uri_str.nil?

      # Convert all backslashes in the URI to forward slashes
      uri_str.gsub!('\\','/')

      # Strip any leading and trailing whitespace
      uri_str.strip!

      scheme, userinfo, host, port, registry, path, opaque, query, fragment = URI.split(URI.encode(uri_str))
      return scheme
    end
  end

  def requires_credentials?
    case self.uri_prefix
    when 'nfs'
      false
    else
      true
    end
  end

  def validate_depot_credentials
    # This only checks that credentials are present
    errors.add(:file_depot, "is missing credentials") if self.requires_credentials? && self.missing_credentials?
  end

  def verify_depot_credentials(auth_type=nil)
    self.class.verify_depot_settings(self.depot_settings(true))
  end

  def depot_settings(reload = false)
    return @depot_settings if !reload && @depot_settings
    return @depot_settings = {
      :uri        => self.uri,
      :uri_prefix => self.uri_prefix,
      :username   => self.authentication_userid,
      :password   => self.authentication_password
    }
  end

  def mnt
    raise "No credentials defined" if self.requires_credentials? && self.missing_credentials?

    return @mnt if @mnt
    @mnt = self.class.mnt_instance(self.depot_settings)
  end

  #
  # API methods
  #

  def connect_depot
    @connected ||= 0
    self.mnt.connect if @connected == 0
    @connected += 1
  end

  def disconnect_depot
    @connected ||= 0
    return if @connected == 0
    self.mnt.disconnect if @connected == 1
    @connected -= 1
  end
  alias :close :disconnect_depot  # TODO: Do we still need this alias?  Since this is a mixin, close is a bad override.

  def with_depot
    connect_depot
    yield
  ensure
    disconnect_depot
  end

  def depot_root
    with_depot do
      self.mnt.mnt_point
    end
  end

  def file_exists?(file)
    with_depot do
      !self.mnt.glob(file).empty?
    end
  end

  def file_glob(pattern)
    with_depot do
      self.mnt.glob(pattern)
    end
  end

  def file_stat(file)
    with_depot do
      self.mnt.stat(file)
    end
  end

  def file_read(file)
    with_depot do
      self.mnt.read(file)
    end
  end

  def file_write(file, contents)
    with_depot do
      self.mnt.write(file, contents)
    end
  end

  def file_delete(file)
    with_depot do
      self.mnt.delete(file)
    end
  end
  alias directory_delete file_delete

  def file_open(*args, &block)
    with_depot do
      self.mnt.open(*args, &block)
    end
  end

  def file_add(source, dest_uri)
    with_depot do
      self.mnt.add(source, dest_uri)
    end
  end

  def file_remove(uri)
    with_depot do
      self.mnt.remove(uri)
    end
  end

  def file_download(local_file, remote_file)
    with_depot do
      self.mnt.download(local_file, remote_file)
    end
  end

  def file_file?(file)
    with_depot do
      self.mnt.file?(file)
    end
  end

  #
  # Callback methods
  #

  def verify_uri_prefix_before_save
    self.uri_prefix = self.class.get_uri_prefix(self.uri)
  end
end

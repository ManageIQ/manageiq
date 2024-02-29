require 'uri'
require 'mount/miq_generic_mount_session'

module FileDepotMixin
  extend ActiveSupport::Concern
  SUPPORTED_DEPOTS = {
    'smb'   => 'Samba',
    'nfs'   => 'Network File System',
    's3'    => 'Amazon Web Services',
    'swift' => 'OpenStack Swift'
  }.freeze

  included do
    include AuthenticationMixin
    before_save :verify_uri_prefix_before_save
  end

  module ClassMethods
    def verify_depot_settings(settings)
      return true unless MiqEnvironment::Command.is_appliance?

      settings["password"] ||= find(settings["id"]).authentication_password if settings["id"]
      res = mnt_instance(settings).verify
      raise _("Connection Settings validation failed with error: %{error}") % {:error => res.last} unless res.first

      res
    end

    def verify_depot_settings_queue(userid, zone, options)
      task_opts = {
        :action => "Verify #{display_name} Credentials",
        :userid => userid
      }

      queue_opts = {
        :class_name  => name,
        :method_name => "verify_depot_settings",
        :args        => [options],
        :zone        => zone
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end

    def mnt_instance(settings)
      settings[:uri_prefix] ||= get_uri_prefix(settings[:uri])
      klass = "Miq#{settings[:uri_prefix].capitalize}Session".constantize
      klass.new(settings)
    end

    def get_uri_prefix(uri_str)
      return nil if uri_str.nil?

      # Convert all backslashes in the URI to forward slashes
      uri_str.tr!('\\', '/')

      # Strip any leading and trailing whitespace
      uri_str.strip!

      scheme, _userinfo, _host, _port, _registry, _path, _opaque, _query, _fragment = URI.split(URI::DEFAULT_PARSER.escape(uri_str))
      scheme
    end
  end

  def requires_credentials?
    case uri_prefix
    when 'nfs'
      false
    else
      true
    end
  end

  def validate_depot_credentials
    # This only checks that credentials are present
    errors.add(:file_depot, "is missing credentials") if requires_credentials? && missing_credentials?
  end

  def verify_depot_credentials(_auth_type = nil)
    self.class.verify_depot_settings(depot_settings(true))
  end

  def depot_settings(reload = false)
    return @depot_settings if !reload && @depot_settings

    @depot_settings = {
      :uri        => uri,
      :uri_prefix => uri_prefix,
      :username   => authentication_userid,
      :password   => authentication_password
    }
  end

  def mnt
    raise _("No credentials defined") if requires_credentials? && missing_credentials?

    return @mnt if @mnt

    @mnt = self.class.mnt_instance(depot_settings)
  end

  #
  # API methods
  #

  def connect_depot
    @connected ||= 0
    mnt.connect if @connected == 0
    @connected += 1
  end

  def disconnect_depot
    @connected ||= 0
    return if @connected == 0

    mnt.disconnect if @connected == 1
    @connected -= 1
  end
  alias close disconnect_depot # TODO: Do we still need this alias?  Since this is a mixin, close is a bad override.

  def with_depot
    connect_depot
    yield
  ensure
    disconnect_depot
  end

  def depot_root
    with_depot do
      mnt.mnt_point
    end
  end

  def file_exists?(file)
    with_depot do
      !mnt.glob(file).empty?
    end
  end

  def file_glob(pattern)
    with_depot do
      mnt.glob(pattern)
    end
  end

  def file_stat(file)
    with_depot do
      mnt.stat(file)
    end
  end

  def file_read(file)
    with_depot do
      mnt.read(file)
    end
  end

  def file_write(file, contents)
    with_depot do
      mnt.write(file, contents)
    end
  end

  def file_delete(file)
    with_depot do
      mnt.delete(file)
    end
  end
  alias directory_delete file_delete

  def file_open(...)
    with_depot do
      mnt.open(...)
    end
  end

  def file_add(source, dest_uri)
    with_depot do
      mnt.add(source, dest_uri)
    end
  end

  def file_remove(uri)
    with_depot do
      mnt.remove(uri)
    end
  end

  def file_download(local_file, remote_file)
    with_depot do
      mnt.download(local_file, remote_file)
    end
  end

  def file_file?(file)
    with_depot do
      mnt.file?(file)
    end
  end

  #
  # Callback methods
  #

  def verify_uri_prefix_before_save
    self.uri_prefix = self.class.get_uri_prefix(uri)
  end
end

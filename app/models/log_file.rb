require 'uri'
require 'mount/miq_generic_mount_session'

class LogFile < ApplicationRecord
  belongs_to :resource,    :polymorphic => true
  belongs_to :file_depot
  belongs_to :miq_task

  LOG_REQUEST_TIMEOUT = 30.minutes

  cattr_reader :log_request_timeout

  before_destroy :remove

  def relative_path_for_upload(loc_file)
    server      = resource
    zone        = server.zone
    path        = "#{zone.name}_#{zone.id}", "#{server.name}_#{server.id}"
    date_string = "#{format_log_time(logging_started_on)}_#{format_log_time(logging_ended_on)}"
    fname       = "#{File.basename(loc_file, ".*").capitalize}_"
    fname += "region_#{MiqRegion.my_region.region rescue "unknown"}_#{zone.name}_#{zone.id}_#{server.name}_#{server.id}_#{date_string}#{File.extname(loc_file)}"
    dest        = File.join("/", path, fname)
    _log.info("Built relative path: [#{dest}] from source: [#{loc_file}]")
    dest
  end

  # Base is the URI defined by the user
  # loc_file is the name of the original file
  def build_log_uri(base_uri, loc_file)
    scheme, userinfo, host, port, registry, path, opaque, query, fragment = URI.split(URI::DEFAULT_PARSER.escape(base_uri))

    # Convert encoded spaces back to spaces
    path.gsub!('%20', ' ')

    relpath  = relative_path_for_upload(loc_file)
    new_path = File.join("/", path, relpath)
    uri      = URI::HTTP.new(scheme, userinfo, host, port, registry, new_path, opaque, query, fragment).to_s
    _log.info("New URI: [#{uri}] from base: [#{base_uri}], and relative path: [#{relpath}]")
    uri
  end

  def upload
    # TODO: Currently the ftp code in the LogFile class has LogFile logic for the destination folders (evm_1/server_1) and builds these paths and copies the logs
    # appropriately.  To make all the various mechanisms work, we need to build a destination URI based on the input filename and pass this along
    # so that the nfs, ftp, smb, etc. mechanism have very little LogFile logic and only need to know how decipher the URI and build the directories as appropraite.
    raise _("LogFile local_file is nil") unless local_file
    unless File.exist?(local_file)
      raise _("LogFile local_file: [%{file_name}] does not exist!") % {:file_name => local_file}
    end
    raise _("Log Depot settings not configured") unless file_depot

    method = get_post_method(file_depot.uri)
    send(:"upload_log_file_#{method}")
  end

  def remove
    method = get_post_method(log_uri)
    return if method.nil?
    return send(:"remove_log_file_#{method}") if respond_to?(:"remove_log_file_#{method}")

    # At this point ftp should have returned
    klass = Object.const_get("Miq#{method.capitalize}Session")
    klass.new(legacy_depot_hash).remove(log_uri)
  rescue Exception => err
    _log.warn("#{err.message}, deleting #{log_uri} from FTP")
  end

  def file_exists?
    return true if log_uri.nil?

    method = get_post_method(log_uri)
    return true if method.nil?
    return send(:"file_exists_#{method}?") if respond_to?(:"file_exists_#{method}?")

    # At this point ftp should have returned
    klass = Object.const_get("Miq#{method.capitalize}Session")
    klass.new(legacy_depot_hash).exist?(log_uri)
  end

  def self.historical_logfile
    empty_logfile(true)
  end

  def self.current_logfile
    empty_logfile(false)
  end

  def self.empty_logfile(historical)
    LogFile.create(:state       => "collecting",
                   :historical  => historical,
                   :description => "Default logfile")
  end

  def upload_log_file_ftp
    file_depot.upload_file(self)
  end

  def upload_log_file_nfs
    uri_to_add = build_log_uri(file_depot.uri, local_file)
    uri        = MiqNfsSession.new(legacy_depot_hash).add(local_file, uri_to_add)
    update(
      :state   => "available",
      :log_uri => uri
    )
    post_upload_tasks
  end

  def upload_log_file_smb
    uri_to_add = build_log_uri(file_depot.uri, local_file)
    uri        = MiqSmbSession.new(legacy_depot_hash).add(local_file, uri_to_add)
    update(
      :state   => "available",
      :log_uri => uri
    )
    post_upload_tasks
  end

  def remove_log_file_ftp
    file_depot.remove_file(self)
  end

  def destination_directory
    File.join("#{resource.zone.name}_#{resource.zone.id}", "#{resource.name}_#{resource.id}")
  end

  def self.logfile_name(resource, category = "Current", date_string = nil)
    region = MiqRegion.my_region.try(:region) || "unknown"
    [category, "region", region, resource.zone.name, resource.zone.id, resource.name, resource.id, date_string].compact.join(" ")
  end

  def destination_file_name
    name.gsub(/\s+/, "_").concat(File.extname(local_file))
  end

  def name
    super || self.class.logfile_name(resource)
  end

  def post_upload_tasks
    FileUtils.rm_f(local_file) if File.exist?(local_file)
  end

  def format_log_time(time)
    time.respond_to?(:strftime) ? time.strftime("%Y%m%d_%H%M%S") : "unknown"
  end

  private

  def get_post_method(uri)
    return nil if uri.nil?

    # Convert all backslashes in the URI to forward slashes
    uri.tr!('\\', '/')

    # Strip any leading and trailing whitespace
    uri.strip!

    URI.split(URI::DEFAULT_PARSER.escape(uri))[0]
  end

  def legacy_depot_hash
    # TODO: Delete this and make FileDepotSmb and FileDepotNfs implement all of their upload/delete/etc. logic
    {
      :uri      => file_depot.uri,
      :username => file_depot.authentication_userid,
      :password => file_depot.authentication_password,
    }
  end
end

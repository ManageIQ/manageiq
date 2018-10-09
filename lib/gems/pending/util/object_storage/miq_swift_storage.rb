require 'pp'
# require 'util/miq_object_storage'
require 'util/mount/miq_generic_mount_session'

class MiqSwiftStorage < MiqObjectStorage
  attr_reader :container_name

  def self.uri_scheme
    "swift".freeze
  end

  def self.new_with_opts(opts)
    new(opts.slice(:uri, :username, :password))
  end

  def initialize(settings)
    super(settings)

    # NOTE: This line to be removed once manageiq-ui-class region change implemented.
    @bucket_name         = URI(@settings[:uri]).host

    raise "username and password are required values!" if @settings[:username].nil? || @settings[:password].nil?
    _scheme, _userinfo, @host, @port, _registry, @mount_path, _opaque, query, _fragment = URI.split(URI.encode(@settings[:uri]))
    query_params(query)
    @swift          = nil
    @username       = @settings[:username]
    @password       = @settings[:password]
    @container_name = @mount_path[0] == File::Separator ? @mount_path[1..-1] : @mount_path
  end

  def uri_to_local_path(remote_file)
    # Strip off the leading "swift:/" from the URI"
    File.join(@mnt_point, URI(remote_file).host, URI(remote_file).path)
  end

  def uri_to_object_path(remote_file)
    # Strip off the leading "swift://" and the container name from the URI"
    # Also remove teh leading delimiter.
    object_file_with_bucket = URI.split(URI.encode(remote_file))[5]
    object_file_with_bucket.split(File::Separator)[2..-1].join(File::Separator)
  end

  def upload_single(dest_uri)
    #
    # Get the remote path, and parse out the bucket name.
    #
    object_file = uri_to_object_path(dest_uri)
    #
    # write dump file to swift
    #
    logger.debug("Writing [#{source_input}] to => Bucket [#{container_name}] using object file name [#{object_file}]")
    begin
      swift_file = container.files.new(:key => object_file)
      params     = {
        :expects       => [201, 202],
        :headers       => {},
        :request_block => -> { read_single_chunk },
        :idempotent    => false,
        :method        => "PUT",
        :path          => "#{Fog::OpenStack.escape(swift_file.directory.key)}/#{Fog::OpenStack.escape(swift_file.key)}"
      }
      swift_file.service.send(:request, params)
      clear_split_vars
    rescue Excon::Errors::Unauthorized => err
      logger.error("Access to Swift container #{@container_name} failed due to a bad username or password. #{err}")
      msg = "Access to Swift container #{@container_name} failed due to a bad username or password. #{err}"
      raise err, msg, err.backtrace
    rescue => err
      logger.error("Error uploading #{source_input} to Swift container #{@container_name}. #{err}")
      msg = "Error uploading #{source_input} to Swift container #{@container_name}. #{err}"
      raise err, msg, err.backtrace
    end
  end

  def mkdir(_dir)
    container
  end

  def container
    @container ||= begin
                     container   = swift.directories.get(container_name)
                     logger.debug("Swift container [#{container}] found") if container
                     container ||= create_container
                     container
                   rescue Fog::Storage::OpenStack::NotFound
                     logger.debug("Swift container #{container_name} does not exist.  Creating.")
                     create_container
                   rescue => err
                     logger.error("Error getting Swift container #{container_name}. #{err}")
                     msg = "Error getting Swift container #{container_name}. #{err}"
                     raise err, msg, err.backtrace
                   end
  end

  private

  def swift
    return @swift if @swift
    require 'manageiq/providers/openstack/legacy/openstack_handle'
    extra_options = {}
    extra_options[:domain_id] = @domain_id
    extra_options[:service] = "Compute"
     @osh ||= OpenstackHandle::Handle.new(@username, @password, @host, @port, @api_version, @security_protocol, extra_options)
    begin
      @swift ||= @osh.swift_service
    rescue Excon::Errors::Unauthorized => err
      logger.error("Access to Swift host #{@host} failed due to a bad username or password. #{err}")
      msg = "Access to Swift host #{@host} failed due to a bad username or password. #{err}"
      raise err, msg, err.backtrace
    rescue => err
      logger.error("Error connecting to Swift host #{@host}. #{err}")
      msg = "Error connecting to Swift host #{@host}. #{err}"
      raise err, msg, err.backtrace
    end
  end

  def create_container
    container = swift.directories.create(:key => container_name)
    logger.debug("Swift container [#{container}] created")
    container
  rescue => err
    logger.error("Error creating Swift container #{container_name}. #{err}")
    msg = "Error creating Swift container #{container_name}. #{err}"
    raise err, msg, err.backtrace
  end

  def download_single(source, destination)
    object_key = @container_name
    logger.debug("Downloading [#{source}] from bucket [#{bucket_name}] to local file [#{destination}]")

    with_standard_s3_error_handling("downloading", source) do
      if destination.kind_of?(IO)
        s3.client.get_object(:bucket => bucket_name, :key => object_key) do |chunk|
          destination.write(chunk)
        end
      else # assume file path
        bucket.object(source).download_file(destination)
      end
    end
    local_file
  end

  def query_params(query_string)
    parts = URI.decode_www_form(query_string).to_h
    @region, @api_version, @domain_id, @security_protocol = parts.values_at("region", "api_version", "domain_id", "security_protocol")
  end
end

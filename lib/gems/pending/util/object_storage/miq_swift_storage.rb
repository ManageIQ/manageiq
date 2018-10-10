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
    # Also remove the leading delimiter.
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
      msg = "Access to Swift container #{@container_name} failed due to a bad username or password. #{err}"
      logger.error(msg)
      raise err, msg, err.backtrace
    rescue => err
      msg = "Error uploading #{source_input} to Swift container #{@container_name}. #{err}"
      logger.error(msg)
      raise err, msg, err.backtrace
    end
  end

  def mkdir(_dir)
    container
  end


  #
  # Some calls to Fog::Storage::OpenStack::Directories#get will
  # return 'nil', and not return an error.  This would cause errors down the
  # line.
  #
  # Instead of investigating further, we created a new method that is in charge of
  # OpenStack container creation, and that is called from '#container' if 'nil' is
  # returned, or the error for 'NotFound' is called to cover both cases.
  #
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
                     msg = "Error getting Swift container #{container_name}. #{err}"
                     logger.error(msg)
                     raise err, msg, err.backtrace
                   end
  end

  private

  def swift
    return @swift if @swift
    require 'fog/openstack'

    auth_url = URI::Generic.build(
      :scheme => @security_protocol == 'non-ssl' ? "http" : "https",
      :host   => @host,
      :port   => @port.to_i,
      :path   => "/#{@api_version}#{@api_version == "v3" ? "/auth" : ".0"}/tokens"
    ).to_s

    connection_params = {
      :openstack_auth_url          => auth_url,
      :openstack_username          => @username,
      :openstack_api_key           => @password,
      :openstack_project_domain_id => @domain_id,
      :openstack_user_domain_id    => @domain_id,
      :openstack_region            => @region,
      :connection_options          => { :debug_request => true }
    }

    @swift = Fog::Storage::OpenStack.new(connection_params)
  end

  def create_container
    container = swift.directories.create(:key => container_name)
    logger.debug("Swift container [#{container_name}] created")
    container
  rescue => err
    msg = "Error creating Swift container #{container_name}. #{err}"
    logger.error(msg)
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

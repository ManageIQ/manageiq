require 'util/miq_object_storage'

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
    @bucket_name = URI(@settings[:uri]).host

    raise "username and password are required values!" if @settings[:username].nil? || @settings[:password].nil?
    _scheme, _userinfo, @host, @port, _registry, path, _opaque, query, _fragment = URI.split(URI.encode(@settings[:uri]))
    query_params(query) if query
    @swift          = nil
    @username       = @settings[:username]
    @password       = @settings[:password]

    # Omit leading slash (if it exists), and grab the rest of the characters
    # before the next file separator
    @container_name = path.gsub(/^\/?([^\/]+)\/.*/, '\1')
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
      #
      # Because of how `Fog::OpenStack` (and probably `Fog::Core`) is designed,
      # it has hidden the functionality to provide a block for streaming
      # uploads that is available out of the box with Excon.
      #
      # we use .send here because #request is private
      #
      # we can't use #put_object (public) directly because it doesn't allow a
      # 202 response code, which is what swift responds with when we pass it
      # the :request_block (This allows us to stream the response in chunks)
      #
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

  def download_single(source, destination)
    object_file = uri_to_object_path(source)
    logger.debug("Downloading [#{source}] from Container [#{container_name}] to local file [#{destination}]")

    with_standard_swift_error_handling("downloading") do
      container_key = container.key # also makes sure 'fog/openstack' is loaded
      params        = {
        :expects        => [200, 206],
        :headers        => {},
        :response_block => write_chunk_proc(destination),
        :method         => "GET",
        :path           => "#{Fog::OpenStack.escape(container_key)}/#{Fog::OpenStack.escape(object_file)}"
      }
      # Range is indexed starting at zero
      params[:headers]['Range'] = "bytes=0-#{byte_count - 1}" if byte_count
      swift.send(:request, params)
    end
  end

  def mkdir(_dir)
    container
  end

  #
  # Some calls to Fog::Storage::OpenStack::Directories#get will
  # return 'nil', and not return an error.  This would cause errors down the
  # line in '#upload' or '#download'.
  #
  # Instead of investigating further, we created a new method that is in charge of
  # OpenStack container creation, '#create_container', and that is called from '#container'
  # if 'nil' is returned from 'swift.directories.get(container_name)', or in the rescue case
  # for 'NotFound' to cover that scenario as well
  #

  def container(create_if_missing = true)
    @container ||= begin
                     container = swift.directories.get(container_name)
                     logger.debug("Swift container [#{container}] found") if container
                     raise Fog::Storage::OpenStack::NotFound unless container
                     container
                   rescue Fog::Storage::OpenStack::NotFound
                     if create_if_missing
                       logger.debug("Swift container #{container_name} does not exist.  Creating.")
                       create_container
                     else
                       msg = "Swift container #{container_name} does not exist.  #{err}"
                       logger.error(msg)
                       raise err, msg, err.backtrace
                     end
                   rescue => err
                     msg = "Error getting Swift container #{container_name}. #{err}"
                     logger.error(msg)
                     raise err, msg, err.backtrace
                   end
  end

  private

  def auth_url
    URI::Generic.build(
      :scheme => @security_protocol == 'non-ssl' ? "http" : "https",
      :host   => @host,
      :port   => @port.to_i,
      :path   => "/#{@api_version}#{@api_version == "v3" ? "/auth" : ".0"}/tokens"
    ).to_s
  end

  def swift
    return @swift if @swift
    require 'fog/openstack'

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

  def query_params(query_string)
    parts = URI.decode_www_form(query_string).to_h
    @region, @api_version, @domain_id, @security_protocol = parts.values_at("region", "api_version", "domain_id", "security_protocol")
  end
end

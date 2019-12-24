require 'util/miq_object_storage'

class MiqS3Storage < MiqObjectStorage
  attr_reader :bucket_name

  def self.uri_scheme
    "s3".freeze
  end

  def self.new_with_opts(opts)
    new(opts.slice(:uri, :username, :password, :region))
  end

  def initialize(settings)
    super(settings)

    # NOTE: This line to be removed once manageiq-ui-class region change implemented.
    @settings[:region] ||= "us-east-1"
    @bucket_name         = URI(@settings[:uri]).host

    raise "username, password, and region are required values!" if @settings[:username].nil? || @settings[:password].nil? || @settings[:region].nil?
  end

  # Extract the path from the URI, so strip off the "s3://" scheme, the bucket
  # hostname, leaving only the path minus the leading '/'
  def uri_to_object_key(remote_file)
    # `path` is `[5]` in the returned result of URI.split
    URI.split(remote_file)[5][1..-1]
  end

  def upload_single(dest_uri)
    object_key = uri_to_object_key(dest_uri)
    logger.debug("Writing [#{source_input}] to => Bucket [#{bucket_name}] Key [#{dest_uri}]")

    with_standard_s3_error_handling("uploading", source_input) do
      bucket.object(object_key).upload_stream do |write_stream|
        IO.copy_stream(source_input, write_stream, byte_count)
      end
    end
  end

  def download_single(source, destination)
    object_key = uri_to_object_key(source)
    logger.debug("Downloading [#{source}] from bucket [#{bucket_name}] to local file [#{destination}]")

    with_standard_s3_error_handling("downloading", source) do
      if destination.kind_of?(IO) || destination.kind_of?(StringIO)
        get_object_opts = {
          :bucket => bucket_name,
          :key    => object_key
        }
        # :range is indexed starting at zero
        get_object_opts[:range] = "bytes=0-#{byte_count - 1}" if byte_count

        s3.client.get_object(get_object_opts, &write_chunk_proc(destination))
      else # assume file path
        bucket.object(source).download_file(destination)
      end
    end
  end

  # no-op mostly
  #
  # dirs don't need to be created ahead of time in s3, unlike mounted file
  # systems.
  #
  # For convenience though, calling bucket, which will initialize and create
  # (if needed) the s3 bucket to be used for this instance.
  def mkdir(_dir)
    bucket
  end

  def bucket
    @bucket ||= s3.bucket(bucket_name).tap do |bucket|
      if bucket.exists?
        logger.debug("Found bucket #{bucket_name}")
      else
        logger.debug("Bucket #{bucket_name} does not exist, creating.")
        bucket.create
      end
    end
  end

  private

  def s3
    require 'aws-sdk-s3'

    @s3 ||= Aws::S3::Resource.new(:region            => @settings[:region],
                                  :access_key_id     => @settings[:username],
                                  :secret_access_key => @settings[:password])
  end

  def with_standard_s3_error_handling(action, object)
    yield
  rescue Aws::S3::Errors::AccessDenied, Aws::S3::Errors::Forbidden => err
    logger.error("Access to S3 bucket #{bucket_name} restricted.  Try a different name. #{err}")
    msg = "Access to S3 bucket #{bucket_name} restricted.  Try a different name. #{err}"
    raise err, msg, err.backtrace
  rescue => err
    logger.error("Error #{action} #{object} from S3. #{err}")
    msg = "Error #{action} #{object} from S3. #{err}"
    raise err, msg, err.backtrace
  end
end

require 'util/miq_ftp_lib'
require 'util/miq_object_storage'
require 'logger'

class MiqFtpStorage < MiqObjectStorage
  include MiqFtpLib

  attr_reader :uri, :username, :password

  def self.uri_scheme
    "ftp".freeze
  end

  def self.new_with_opts(opts)
    new(opts.slice(:uri, :username, :password))
  end

  def initialize(settings)
    super
    @uri      = @settings[:uri]
    @username = @settings[:username]
    @password = @settings[:password]
  end

  # Override for connection handling
  def add(*upload_args)
    with_connection { super }
  end

  # Override for connection handling
  def download(*download_args)
    with_connection { super }
  end

  # Specific version of Net::FTP#storbinary that doesn't use an existing local
  # file, and only uploads a specific size (byte_count) from the input_file
  def upload_single(dest_uri)
    ftp.synchronize do
      ftp.send(:with_binary, true) do
        conn = ftp.send(:transfercmd, "STOR #{uri_to_relative(dest_uri)}")
        IO.copy_stream(source_input, conn, byte_count)
        conn.close
        ftp.send(:voidresp)
      end
    end
    dest_uri
  rescue Errno::EPIPE
    # EPIPE, in this case, means that the data connection was unexpectedly
    # terminated.  Rather than just raising EPIPE to the caller, check the
    # response on the control connection.  If getresp doesn't raise a more
    # appropriate exception, re-raise the original exception.
    ftp.send(:getresp)
    raise
  end

  def download_single(source, destination)
    ftp.getbinaryfile(uri_to_relative(source), destination)
  end

  def mkdir(dir)
    create_directory_structure(uri_to_relative(dir))
  end

  private

  def login_credentials
    [username, password].compact
  end

  # Currently assumes you have just connected and are at the root logged in
  # dir.  Net::FTP (or ftp in general) doesn't seem to have a concept of a
  # "root dir" based on your login, so this should be used right after
  # `.connect`, or shortly there after.
  #
  # Or, you should be returning to the directory you came from prior to using
  # this method again, or not using `ftp.chdir` at all.
  def uri_to_relative(filepath)
    result = URI.split(filepath)[5]
    result = result[1..-1] if result[0] == "/".freeze
    result
  end

  def _log
    logger
  end
end

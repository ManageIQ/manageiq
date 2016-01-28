require 'winrm'

class MiqWinRM
  attr_reader :uri, :username, :password, :hostname, :port, :connection, :executor

  def initialize
    @port = 5985
    require 'uri'
  end

  def build_uri
    uri = URI::HTTP.build(:port => @port, :path => "/wsman", :host => @hostname)
    uri.to_s
  end

  def connect(options = {})
    validate_options(options)
    @uri        = build_uri
    @connection = raw_connect(@username, @password, @uri)
    @executor   = @connection.create_executor
  end

  def run_powershell_script(script)
    $log.debug "Running powershell script on #{hostname} as #{username}:\n#{script}" unless $log.nil?
    @executor.run_powershell_script(script)
  rescue WinRM::WinRMAuthorizationError
    $log.info "Error Logging In to #{hostname} using user \"#{username}\"" unless $log.nil?
    raise
  end

  private

  def validate_options(options)
    raise "no Username defined" if options[:user].nil?
    raise "no Password defined" if options[:pass].nil?
    raise "no Hostname defined" if options[:hostname].nil?
    @username = options[:user]
    @password = options[:pass]
    @hostname = options[:hostname]
    @port     = options[:port] unless options[:port].nil?
  end

  def raw_connect(user, pass, uri)
    # HACK: WinRM depends on the gssapi gem for encryption purposes.
    # The gssapi code outputs the following warning:
    #   WARNING: Could not load IOV methods. Check your GSSAPI C library for an update
    #   WARNING: Could not load AEAD methods. Check your GSSAPI C library for an update
    # After much googling, this warning is considered benign and can be ignored.
    # Please note - the webmock gem depends on gssapi too and prints out the
    # above warning when rspec tests are run.
    # silence_warnings { require 'winrm' }

    WinRM::WinRMWebService.new(uri, :ssl, :user => user, :pass => pass, :disable_sspi => true)
  end
end

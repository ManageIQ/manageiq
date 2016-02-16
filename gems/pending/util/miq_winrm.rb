require 'winrm'
require 'winrm-elevated'

class MiqWinRM
  attr_reader :uri, :username, :password, :hostname, :port, :connection, :executor

  def initialize
    @port            = 5985
    @elevated_runner = @executor = nil
    require 'uri'
  end

  def build_uri
    URI::HTTP.build(:port => @port, :path => "/wsman", :host => @hostname).to_s
  end

  def connect(options = {})
    validate_options(options)
    @uri        = build_uri
    @connection = raw_connect(@username, @password, @uri)
  end

  def execute
    @executor = @connection.create_executor
  end

  def elevate
    @elevated_runner = WinRM::Elevated::Runner.new(@connection)
  end

  def run_powershell_script(script)
    execute if @executor.nil?
    $log.debug "Running powershell script on #{hostname} as #{username}:\n#{script}" unless $log.nil?
    @executor.run_powershell_script(script)
  rescue WinRM::WinRMAuthorizationError
    $log.info "Error Logging In to #{hostname} using user \"#{username}\"" unless $log.nil?
    raise
  rescue WinRM::WinRMWMIError => error
    $log.debug "Error Running Powershell on #{hostname} using user \"#{username}\": #{error}" unless $log.nil?
    if error.to_s.include? "This user is allowed a maximum number of "
      $log.debug "Re-opening connection and retrying" unless $log.nil?
      @executor.close
      @executor        = nil 
      @connection      = raw_connect(@username, @password, @uri) if @elevated_runner
      @elevated_runner = nil
      retry
    else
      raise
    end
  end

  def run_elevated_powershell_script(script)
    elevate if @elevated_runner.nil?
    $log.debug "Running powershell script elevated on #{hostname} as #{username}:\n#{script}" unless $log.nil?
    @elevated_runner.powershell_elevated(script, @username, @password)
  rescue WinRM::WinRMAuthorizationError
    $log.info "Error Logging In to #{hostname} using user \"#{username}\"" unless $log.nil?
    raise
  rescue WinRM::WinRMWMIError => error
    $log.debug "Error Running Powershell on #{hostname} using user \"#{username}\": #{error}" unless $log.nil?
    if error.to_s.include? "This user is allowed a maximum number of "
      $log.debug "Re-opening connection and retrying" unless $log.nil?
      @connection      = raw_connect(@username, @password, @uri)
      @elevated_runner = nil
      @executor.close if @executor
      @executor = nil 
      retry
    else
      raise
    end
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

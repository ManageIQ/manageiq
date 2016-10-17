require 'winrm'
require 'winrm-elevated'

class MiqWinRM
  WMI_RETRIES = 2
  attr_reader :uri, :username, :password, :hostname, :port, :connection

  def initialize
    @port            = 5985
    @shell           = nil
    @elevated_runner = nil
    require 'uri'
  end

  def build_uri
    URI::HTTP.build(:port => @port, :path => "/wsman", :host => @hostname).to_s
  end

  def connect(options = {})
    validate_options(options)
    options[:endpoint] = build_uri
    @options           = options
    @connection        = raw_connect(options)
  end

  def close
    @shell.close if @shell
  end

  def execute
    @shell = @connection.shell(:powershell)
  end

  def elevate
    @shell           = @connection.shell(:elevated)
    @elevated_runner = true
  end

  def run_powershell_script(script)
    wmi_error_retries = 0
    begin
      execute if @shell.nil?
      $log.debug "Running powershell script on #{hostname} as #{username}:\n#{script}" if $log
      @shell.run(script)
    rescue WinRM::WinRMAuthorizationError
      $log.info "Error Logging In to #{hostname} using user \"#{username}\"" if $log
      raise
    rescue WinRM::WinRMWMIError => error
      $log.debug "Error Running Powershell on #{hostname} using user \"#{username}\": #{error}" if $log
      raise if wmi_error_retries > WMI_RETRIES
      wmi_error_retries += 1
      if error.to_s.include? "This user is allowed a maximum number of "
        $log.debug "Re-opening connection and retrying" if $log
        @shell.close
        @shell      = nil
        @connection = raw_connect(@options)
        execute
        retry
      else
        raise
      end
    end
  end

  def run_elevated_powershell_script(script)
    wmi_error_retries = 0
    begin
      elevate if @elevated_runner.nil?
      $log.debug "Running powershell script elevated on #{hostname} as #{username}:\n#{script}" if $log
      @shell.run(script)
    rescue WinRM::WinRMAuthorizationError
      $log.info "Error Logging In to #{hostname} using user \"#{username}\"" if $log
      raise
    rescue WinRM::WinRMWMIError => error
      $log.debug "Error Running Powershell on #{hostname} using user \"#{username}\": #{error}" if $log
      raise if wmi_error_retries > WMI_RETRIES
      wmi_error_retries += 1
      if error.to_s.include? "This user is allowed a maximum number of "
        $log.debug "Re-opening connection and retrying" if $log
        @shell.close
        @connection      = raw_connect(@options)
        @elevated_runner = nil
        retry
      else
        raise
      end
    end
  end

  # Parse an ugly XML error string into something much more readable.
  #
  def parse_xml_error_string(str)
    require 'nokogiri'
    str = str.sub("#< CLIXML\r\n", '') # Illegal, nokogiri can't cope
    doc = Nokogiri::XML::Document.parse(str)
    doc.remove_namespaces!

    text = doc.xpath("//S").map(&:text).join
    array = text.split(/_x\h{1,}_/) # Split on stuff like '_x000D_'
    array.delete('') # Delete empty elements

    array.inject('') do |string, element|
      break string if element =~ /at line:\d+/i
      string << element
    end
  end

  private

  def validate_options(options)
    raise "no Username defined" if options[:user].nil?
    raise "no Password defined" if options[:password].nil?
    raise "no Hostname defined" if options[:hostname].nil?
    @username = options[:user]
    @password = options[:password]
    @hostname = options[:hostname]
    @port     = options[:port] unless options[:port].nil?
  end

  def raw_connect(opts)
    # HACK: WinRM depends on the gssapi gem for encryption purposes.
    # The gssapi code outputs the following warning:
    #   WARNING: Could not load IOV methods. Check your GSSAPI C library for an update
    #   WARNING: Could not load AEAD methods. Check your GSSAPI C library for an update
    # After much googling, this warning is considered benign and can be ignored.
    # Please note - the webmock gem depends on gssapi too and prints out the
    # above warning when rspec tests are run.
    # silence_warnings { require 'winrm' }

    WinRM::Connection.new(opts)
  end
end

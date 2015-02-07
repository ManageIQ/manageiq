require 'fileutils'

module MiqApache
  # Abstract Apache Error Class
  class Error < RuntimeError; end

  ###################################################################
  #
  # http://httpd.apache.org/docs/2.2/programs/apachectl.html
  #
  ###################################################################
  class Control
    APACHE_CONTROL_LOG = '/var/www/miq/vmdb/log/apache/miq_apache.log'

    def self.start
      ###################################################################
      # Start the Apache httpd daemon. Gives an error if it is already running.
      #
      # Command line: apachectl -k start
      ###################################################################
      self.run_apache_cmd 'start'
    end

    def self.restart(graceful = true)
      if graceful
        ###################################################################
        # Gracefully restarts the Apache httpd daemon. If the daemon is not running, it is started.
        # This differs from a normal restart in that currently open connections are not aborted.
        # A side effect is that old log files will not be closed immediately. This means that if
        # used in a log rotation script, a substantial delay may be necessary to ensure that the
        # old log files are closed before processing them. This command automatically checks the
        # configuration files as in configtest before initiating the restart to make sure Apache
        # doesn't die.
        #
        # Command line: apachectl -k graceful
        ###################################################################
        #
        #FIXME: apache doesn't re-read the proxy balancer members on a graceful restart, so do a graceful stop and start
        #        system('apachectl -k graceful')
        #http://www.gossamer-threads.com/lists/apache/users/383770
        #https://issues.apache.org/bugzilla/show_bug.cgi?id=45950
        #https://issues.apache.org/bugzilla/show_bug.cgi?id=39811
        #https://issues.apache.org/bugzilla/show_bug.cgi?id=44736
        #https://issues.apache.org/bugzilla/show_bug.cgi?id=42621

        self.stop(graceful)
        self.start
      else
        ###################################################################
        # Restarts the Apache httpd daemon. If the daemon is not running, it is started. This
        # command automatically checks the configuration files as in configtest before initiating
        # the restart to make sure the daemon doesn't die.
        #
        # Command line: apachectl -k restart
        ###################################################################
        self.run_apache_cmd 'restart'
      end
    end

    def self.stop(graceful = true)
      if graceful
        ###################################################################
        # Gracefully stops the Apache httpd daemon. This differs from a normal stop in that
        # currently open connections are not aborted. A side effect is that old log files
        # will not be closed immediately.
        #
        # Command line: apachectl -k graceful-stop
        ###################################################################
        self.run_apache_cmd 'graceful-stop'
      else
        ###################################################################
        # Stops the Apache httpd daemon
        #
        # Command line: apachectl -k stop
        ###################################################################
        self.run_apache_cmd 'stop'
      end
    end

    def self.httpd_status
      begin
        res = MiqUtil.runcmd("/etc/init.d/#{ENV['MIQ_APACHE_PACKAGE_NAME']} status")
      rescue RuntimeError => err
        res = err.to_s
        return false, res if res =~ /^httpd (is stopped|dead but pid file exists)$/

      else
        return true, res if res =~ /is running...\n/
      end
      raise "Unknown apache status: #{res}"
    end

    def self.kill_all
      begin
        MiqUtil.runcmd('killall -9 httpd')
      rescue => err
        raise unless err.to_s =~ /httpd: no process killed/
      else
        MiqUtil.runcmd("for i in `ipcs -s | awk '/apache/ {print $2}'`; do (ipcrm -s $i); done")
      end
    end

    def self.status(full = true)
      if full
        ###################################################################
        # Displays a full status report from mod_status. For this to work, you need to have
        # mod_status enabled on your server and a text-based browser such as lynx available
        # on your system. The URL used to access the status report can be set by editing the
        # STATUSURL variable in the script.
        #
        # Command line: apachectl fullstatus
        ###################################################################
      else
        ###################################################################
        # Displays a brief status report. Similar to the fullstatus option, except that
        # the list of requests currently being served is omitted.
        #
        # Command line: apachectl status
        ###################################################################
      end
    end

    def self.version
      MiqUtil.runcmd("rpm -qa --queryformat '%{VERSION}' #{ENV['MIQ_APACHE_PACKAGE_NAME']}")
    end

    def self.config_ok?
      ###################################################################
      # Run a configuration file syntax test. It parses the configuration files and either
      # reports Syntax Ok or detailed information about the particular syntax error.
      #
      # Command line: apachectl configtest
      ###################################################################
      begin
        res = MiqUtil.runcmd('apachectl configtest')
      rescue
        $log.warn("MIQ(MiqApache::Control.config_ok?) Configuration syntax failed with error: #{res}") if $log
        return false
      end
      return true if res =~ /Syntax OK/
      $log.warn("MIQ(MiqApache::Control.config_ok?) Configuration syntax failed with error: #{res}") if $log

      return false
    end

    private
    def self.run_apache_cmd(command)
      Dir.mkdir(File.dirname(APACHE_CONTROL_LOG)) unless File.exist?(File.dirname(APACHE_CONTROL_LOG))
      begin
        cmd = "apachectl -E #{APACHE_CONTROL_LOG} -k #{command}"
        cmd << " -e debug" if $log && $log.debug?
        res = MiqUtil.runcmd(cmd)
      rescue => err
        $log.warn("MIQ(MiqApache::Control.run_apache_cmd) Apache command #{command} with result: #{res} failed with error: #{err}") if $log
      end
    end
  end

  ###################################################################
  #
  # Control Exceptions Definition
  #
  ###################################################################
  class ControlError             < Error; end

  ###################################################################
  #
  # http://httpd.apache.org/docs/2.2/configuring.html
  #
  ###################################################################
  class Conf
    RE_COMMENT = /^\s*(?:\#.*)?$/
    RE_BLOCK_DIRECTIVE_START = /^\s*<([A-Za-z][^\s>]*)\s*([^>]*)>/

    attr_reader :fname
    attr_accessor :raw_lines
    cattr_accessor :instance_cache

    def initialize(filename = nil)
      raise ConfFileNotSpecified if filename.nil?
      raise ConfFileNotFound     unless File.file?(filename)
      @fname     = filename
      self.class.instance_cache = self
      self.reload
    end

    def self.instance(filename)
      if self.instance_cache && self.instance_cache.fname == filename
        self.instance_cache.reload
      else
        self.instance_cache = self.new(filename)
      end
      return self.instance_cache
    end

    def self.install_default_config(opts = {})
      File.write(opts[:member_file],    self.create_balancer_config(opts))
      File.write(opts[:redirects_file], self.create_redirects_config(opts))
    end

    def self.create_balancer_config(opts = {})
      lbmethod = case opts[:lbmethod]
      when :busy;     :bybusyness
      when :traffic;  :bytraffic
      else            :byrequests
      end

      "<Proxy balancer://#{opts[:cluster]}/ lbmethod=#{lbmethod}>\n</Proxy>\n"
    end

    def self.create_redirects_config(opts = {})
      opts[:redirects].to_miq_a.each_with_object("") do |redirect, content|
        content << "ProxyPass /proxy_pages !\n" if redirect == "/"
        content << "ProxyPass #{redirect} balancer://#{opts[:cluster]}#{redirect}\n"
        content << "ProxyPassReverse #{redirect} balancer://#{opts[:cluster]}#{redirect}\n"
      end
    end

    def self.create_conf_file(filename, content)
      raise ConfFileAlreadyExists if File.exist?(filename)

      FileUtils.touch(filename)
      file = self.new(filename)
      file.add_content(content, :update_raw_lines => true)
      file.save
    end

    def add_content(content, options = {})
      content = content.split("\n") if content.kind_of?(String)
      lines   = content.collect { |line| line.kind_of?(Hash) ? create_directive(line) : line }

      options[:update_raw_lines] ? @raw_lines.push(lines.flatten.join("\n")) : lines
    end

    def create_directive(hash)
      raise ArgumentError, ":directive key is required" if hash[:directive].blank?

      open  = "<#{hash[:directive]} #{hash[:attribute]}".strip << ">"
      close = "</#{hash[:directive]}>"

      ["", open, add_content(hash[:configurations]), close, ""]
    end

    def reload
      @raw_lines = File.read(@fname).lines.to_a
    end

    def line_count
      @raw_lines.size
    end

    def content_lines
      # Ignore empty or commented lines
      @raw_lines.delete_if { |line| line =~ RE_COMMENT }
    end

    def block_directives
      @raw_lines.delete_if { |line| line !~ RE_BLOCK_DIRECTIVE_START }
    end

    def add_ports(ports)
      index = @raw_lines.index { |line| line =~ RE_BLOCK_DIRECTIVE_START && $1 == 'Proxy' && $2 =~ /^balancer:\/\/evmcluster[^\s]*\// }

      raise "Proxy section not found in file: #{@fname}" if index.nil?

      ports = Array(ports).sort.reverse
      ports.each do |port|
        @raw_lines.insert(index + 1, "BalancerMember http://0.0.0.0:#{port}\n")
      end
      ports
    end

    def remove_ports(ports)
      ports = Array(ports)
      ports.each do |port|
        @raw_lines.delete_if { |line| line =~ /BalancerMember\s+http:\/\/0\.0\.0\.0:#{port}$/ }
      end
      ports
    end

    def save
      backup = "#{@fname}_old"
      FileUtils.cp(@fname, backup)
      File.write(@fname, @raw_lines.join(""))
      unless Control.config_ok?
        $log.warn("MIQ(MiqApache::Conf.save) Restoring old configuration due to bad configuration!") if $log
        FileUtils.cp(backup, @fname)
        return false
      end
      return true
    end

  end

  ###################################################################
  #
  # Configuration Exceptions Definition
  #
  ##################################################################
  class ConfError             <     Error; end
  class ConfFileAlreadyExists < ConfError; end
  class ConfFileNotSpecified  < ConfError; end
  class ConfFileNotFound      < ConfError; end
  class ConfFileInvalid       < ConfError; end

end

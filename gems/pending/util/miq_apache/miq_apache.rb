require 'fileutils'
require 'logger'
require 'active_support/core_ext/class/attribute_accessors'
require 'util/runcmd'
require 'util/extensions/miq-array'

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
      # Command line: apachectl start
      ###################################################################
      run_apache_cmd 'start'
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
        # Command line: apachectl graceful
        ###################################################################
        #
        # FIXME: apache doesn't re-read the proxy balancer members on a graceful restart, so do a graceful stop and start
        #        system('apachectl graceful')
        # http://www.gossamer-threads.com/lists/apache/users/383770
        # https://issues.apache.org/bugzilla/show_bug.cgi?id=45950
        # https://issues.apache.org/bugzilla/show_bug.cgi?id=39811
        # https://issues.apache.org/bugzilla/show_bug.cgi?id=44736
        # https://issues.apache.org/bugzilla/show_bug.cgi?id=42621

        stop(graceful)
        start
      else
        ###################################################################
        # Restarts the Apache httpd daemon. If the daemon is not running, it is started. This
        # command automatically checks the configuration files as in configtest before initiating
        # the restart to make sure the daemon doesn't die.
        #
        # Command line: apachectl restart
        ###################################################################
        run_apache_cmd 'restart'
      end
    end

    def self.stop(graceful = true)
      if graceful
        ###################################################################
        # Gracefully stops the Apache httpd daemon. This differs from a normal stop in that
        # currently open connections are not aborted. A side effect is that old log files
        # will not be closed immediately.
        #
        # Command line: apachectl graceful-stop
        ###################################################################
        run_apache_cmd 'graceful-stop'
      else
        ###################################################################
        # Stops the Apache httpd daemon
        #
        # Command line: apachectl stop
        ###################################################################
        run_apache_cmd 'stop'
      end
    end

    def self.httpd_status
      begin
        res = MiqUtil.runcmd('/usr/bin/systemctl status httpd')
      rescue RuntimeError => err
        res = err.to_s
        return false, res if res =~ /Active: inactive/

      else
        return true, res if res =~ /Active: active/
      end
      raise "Unknown apache status: #{res}"
    end

    def self.kill_all
      MiqUtil.runcmd('killall -9 httpd')
    rescue => err
      raise unless err.to_s =~ /httpd: no process found/
    else
      MiqUtil.runcmd("for i in `ipcs -s | awk '/apache/ {print $2}'`; do (ipcrm -s $i); done")
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
      end
    end

    def self.version
      MiqUtil.runcmd("rpm -qa --queryformat '%{VERSION}' httpd")
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
      rescue => err
        $log.warn("MIQ(MiqApache::Control.config_ok?) Configuration syntax failed with error: #{err} for result: #{res}") if $log
        return false
      end
      return true if res =~ /Syntax OK/
      $log.warn("MIQ(MiqApache::Control.config_ok?) Configuration syntax failed with error: #{res}") if $log

      false
    end

    private

    def self.run_apache_cmd(command)
      Dir.mkdir(File.dirname(APACHE_CONTROL_LOG)) unless File.exist?(File.dirname(APACHE_CONTROL_LOG))
      begin
        cmd = "apachectl #{command}"
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
  class ControlError < Error; end

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
      reload
    end

    def self.instance(filename)
      if instance_cache && instance_cache.fname == filename
        instance_cache.reload
      else
        self.instance_cache = new(filename)
      end
      instance_cache
    end

    def self.install_default_config(opts = {})
      File.write(opts[:member_file],    create_balancer_config(opts))
      File.write(opts[:redirects_file], create_redirects_config(opts))
    end

    def self.create_balancer_config(opts = {})
      lbmethod = case opts[:lbmethod]
                 when :busy then     :bybusyness
                 when :traffic then  :bytraffic
                 else            :byrequests
                 end

      "<Proxy balancer://#{opts[:cluster]}/ lbmethod=#{lbmethod}>\n</Proxy>\n"
    end

    def self.create_redirects_config(opts = {})
      opts[:redirects].to_miq_a.each_with_object("") do |redirect, content|
        if redirect == "/"
          content << "RewriteRule ^/self_service(?!/(assets|images|img|styles|js|fonts|bower_components|gettext)) /self_service/index.html [L]\n"
          content << "RewriteCond \%{REQUEST_URI} !^/ws\n"
          content << "RewriteCond \%{REQUEST_URI} !^/proxy_pages\n"
          content << "RewriteCond \%{REQUEST_URI} !^/saml2\n"
          content << "RewriteCond \%{REQUEST_URI} !^/api\n"
          content << "RewriteCond \%{DOCUMENT_ROOT}/\%{REQUEST_FILENAME} !-f\n"
          content << "RewriteRule ^#{redirect} balancer://#{opts[:cluster]}\%{REQUEST_URI} [P,QSA,L]\n"
        else
          content << "ProxyPass #{redirect} balancer://#{opts[:cluster]}#{redirect}\n"
        end
        # yes, we want ProxyPassReverse for both ProxyPass AND RewriteRule [P]
        content << "ProxyPassReverse #{redirect} balancer://#{opts[:cluster]}#{redirect}\n"
      end
    end

    def self.create_conf_file(filename, content)
      raise ConfFileAlreadyExists if File.exist?(filename)

      FileUtils.touch(filename)
      file = new(filename)
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

    def add_ports(ports, protocol)
      index = @raw_lines.index { |line| line =~ RE_BLOCK_DIRECTIVE_START && $1 == 'Proxy' && $2 =~ /^balancer:\/\/evmcluster[^\s]*\// }

      raise "Proxy section not found in file: #{@fname}" if index.nil?

      ports = Array(ports).sort.reverse
      ports.each do |port|
        @raw_lines.insert(index + 1, "BalancerMember #{protocol}://0.0.0.0:#{port}\n")
      end
      ports
    end

    def remove_ports(ports, protocol)
      ports = Array(ports)
      ports.each do |port|
        @raw_lines.delete_if { |line| line =~ /BalancerMember\s+#{protocol}:\/\/0\.0\.0\.0:#{port}$/ }
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
      true
    end
  end

  ###################################################################
  #
  # Configuration Exceptions Definition
  #
  ##################################################################
  class ConfError < Error; end
  class ConfFileAlreadyExists < ConfError; end
  class ConfFileNotSpecified < ConfError; end
  class ConfFileNotFound < ConfError; end
  class ConfFileInvalid < ConfError; end
end

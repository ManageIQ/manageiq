require 'fileutils'
require 'logger'
require 'active_support/core_ext/class/attribute_accessors'
require 'util/runcmd'

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

    def self.restart
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

      stop
      start
    end

    def self.start
      if ENV["CONTAINER"]
        system("/usr/sbin/httpd -DFOREGROUND &")
      else
        run_apache_cmd('start')
      end
    end

    def self.stop
      if ENV["CONTAINER"]
        pid = `pgrep -P 1 httpd`.chomp.to_i
        Process.kill("WINCH", pid) if pid > 0
      else
        run_apache_cmd('stop')
      end
    end

    def self.run_apache_cmd(command)
      Dir.mkdir(File.dirname(APACHE_CONTROL_LOG)) unless File.exist?(File.dirname(APACHE_CONTROL_LOG))
      begin
        res = MiqUtil.runcmd("apachectl", :params => [[command]])
      rescue => err
        $log.warn("MIQ(MiqApache::Control.run_apache_cmd) Apache command #{command} with result: #{res} failed with error: #{err}") if $log
      end
    end
    private_class_method :run_apache_cmd
  end
end

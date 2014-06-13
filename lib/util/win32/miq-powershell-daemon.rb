$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/..")
require 'miq-powershell'
require 'miq-process'
require 'miq-password'

module MiqPowerShell
  class Daemon
    def initialize(uri='http://127.0.0.1', port=nil)
      @requested_port = port
      @requested_uri  = uri
      @connected = false
      self.connect
    end

    def connect
      require 'win32/process'

      if @port.nil?
        self.port
      else
        return if self.isAlive?
        self.port
      end

      command = '-NoLogo -NonInteractive -NoProfile -ExecutionPolicy RemoteSigned '
      command += File.join(File.expand_path(File.dirname(__FILE__)), "miq-psd.ps1")
      command += " #{self.uri}"
      ps_log_dir = self.get_log_dir
      command += " #{ps_log_dir}" unless ps_log_dir.blank?

      @pid = MiqPowerShell.execute_async(command)

      # Wait upto 10 seconds for the daemon to start responding
      ps_info = {}
      1.upto(10) do |i|
        ps_info = MiqProcess.processInfo(@pid)
        break if !ps_info.has_key?(:name) || self.isAlive?
        sleep(1)
      end
      # The name key will be missing if the process is no longer running
      if !ps_info.has_key?(:name)
        # TODO: Try to determine why
        #ret = MiqPowerShell.execute(command)
        #puts "!!!!!!!!\n#{ret}\n!!!!!!!!"
        raise "Powershell process started with pid:[#{@pid}] but failed to initialize."
      end

      $log.debug "Powershell daemon running on URI: [#{@uri}]" if $log
    end

    def uri()
      @uri = "#{@requested_uri}:#{@port}/mps/"
    end

    def port()
      @port = @requested_port.nil? ? self.find_free_port : @requested_port
    end

    def disconnect
      return if @pid.nil?
      self.run_script("quit") rescue nil
      @pid = nil
    end

    def run_script(command, ret_type = nil)
      return nil if command.nil? || @pid.nil?

      ret_type ||= :string
      case ret_type.to_sym
      when :xml
        self.run_script_xml(command)
      when :object
        self.run_script_object(command)
      when :xmlpath_xml
        self.run_script_xmlpath_xml(command)
      when :xmlpath_object
        self.run_script_xmlpath_object(command)
      else
        self.run_script_string(command)
      end
    end

    def run_script_string(command)
      uri_command = File.join(@uri, "?cmd=") + MIQEncode.base64Encode(MIQEncode.encode(self.pre_process_script(command), false).chomp())
      #puts "Sending command: [#{uri_command}]"
      meta = {}; data = nil

      global_ps_options = $miqHostCfg ? $miqHostCfg.powershell || {} : {}
      timeout = global_ps_options.has_key?(:timeout) ? global_ps_options[:timeout].to_i : 120

      begin
        $log.debug "Powershell: Waiting for powershell daemon response.  PID: <#{@pid}>  Timeout: <#{timeout}>" if $log
        st = Time.now
        Kernel.open(uri_command, {:read_timeout => timeout}) {|ret| data = ret.read; meta = ret.meta}
      rescue Timeout::Error => err
        $log.error "Powershell daemon timed-out after <#{Time.now-st}> seconds for PID: <#{@pid}>"
        $log.warn "Killing external Powershell process with pid <#{@pid}>"
        MiqPowerShell.kill_process(@pid)
        @pid = nil
        raise
      end
      return data
    end

    def run_script_xml(command)
      # If we're connecting locally force serializing and return filename only
      return run_script_xmlpath_xml(command) if @requested_uri == 'http://127.0.0.1'

      script = command.chomp + MiqPowerShell.pipe_to_xml
      data = self.run_script(script)
      $log.info "Powershell_daemon: Processing results data size: #{data.length}" if $log
      unless data.nil?
        xml = MiqXml.load(data)
        MiqPowerShell.verify_return_object(xml)
        return xml
      end
    end

    # This method takes the last line of the script and marshals it through XML to
    # a Ruby object.
    def run_script_object(command)
      MiqPowerShell.ps_xml_to_hash(self.run_script_xml(command))
    end

    def run_script_xmlpath_xml(command)
      script = command.chomp + MiqPowerShell.pipe_to_xml_path
      data = self.run_script(script)
      data = data[3..-1] # remove UTF-8 BOM
      data = data.Utf8ToAscii.strip

      idx = data.rindex(':')
      xml_file = data[idx-1..-1] unless idx.nil?

      xml = nil
      if File.exist?(xml_file)
        begin
          $log.info "Powershell_daemon: Processing results file <#{xml_file}>  Size: #{File.size(xml_file)}" if $log
          xml = MiqXml.loadFile(xml_file)
        ensure
          File.delete(xml_file)
        end
      else
        if data.blank?
          raise "Powershell Daemon returned no data"
        else
          $log.info "Powershell_daemon: Processing results data <#{data[0,255].inspect}>}" if $log
          # If the script errors out we will get the error back instead of a file name so process it as data
          xml = MiqXml.load(data)
        end
      end

      MiqPowerShell.verify_return_object(xml)
      return xml
    end

    def run_script_xmlpath_object(command)
      MiqPowerShell.ps_xml_to_hash(self.run_script_xmlpath_xml(command))
    end

    def pre_process_script(ps_script)
      script = ps_script.dup
      while script =~ /["']?(v[0-9]+:\{[^}]*\})["']?/
        b64_pwd = Base64.encode64(MiqPassword.decrypt($1)).chomp
        script.sub!($&, "([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(\"#{b64_pwd}\")))")
      end
      return script
    end

    def get_log_messages
      return [] if @pid.nil?
      # This script will return the log array from the ps daemon
      ps_script = <<-PS_SCRIPT
      $result = $global:miq_log_array
      $global:miq_log_array = @()
      $result
      PS_SCRIPT
      log_msgs = run_script_object(ps_script)
      MiqPowerShell.log_messages(log_msgs)
      log_msgs
    end

    def find_free_port
      x = TCPServer.open('127.0.0.1', 0)
      port = x.addr[1]
      x.close
      Thread.pass
      x = nil
      GC.start
      return port
    end

    def isAlive?
      begin
        self.run_script("$true")
      rescue => err
        return false
      end
      return true
    end

    def self.get_log_dir
      return nil unless Platform::OS == :win32
      ps_log_dir = $miqHostCfg ? $miqHostCfg.miqLogs : nil
      unless ps_log_dir.blank?
        ps_log_dir = File.join(ps_log_dir, "ps_log")
        Dir.mkdir(ps_log_dir, 0755) if !File.directory?(ps_log_dir)
      end
      return nil if ps_log_dir.blank?
      File.getShortFileName(ps_log_dir)
    end

    def get_log_dir
      self.class.get_log_dir
    end
  end
end

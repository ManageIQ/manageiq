require 'extensions/miq-string.rb'

module Net
  module SSH
    module Authentication
      class KeyManager
        def use_agent?
          false
        end
      end
    end
  end
end

class MiqSshUtil

  attr_reader :status, :host

  def initialize(host, user, password, options={})
    @host     = host
    @user     = user
    @password = password
    @status   = 0
    @shell    = nil
    @options  = {:password => @password, :remember_host=>false, :verbose => :warn}.merge(options)

    # Pull the 'remember_host' key out of the hash because the SSH initializer will complain
    @remember_host = @options.delete(:remember_host)
    @su_user     = @options.delete(:su_user)
    @su_password = @options.delete(:su_password)

    # Obsolete, delete if passed in
    @options.delete(:authentication_prompt_delay)

    # Set logging to use our default handle if it exists and one was not passed in
    unless @options.has_key?(:logger)
#        @options[:logger] = $log if $log
    end
  end # def initialize
  
  def cp(from, to)
    Net::SFTP.start(@host, @user, :password => @password) do |sftp|
      $log.debug "MiqSshUtil::cp - Copying file #{from} to #{@host}:#{to}." if $log
      sftp.upload!(from, to)
      $log.debug "MiqSshUtil::cp - Copying of #{from} to #{@host}:#{to}, complete." if $log
    end
  end # def cp

  def get_file(from, to)
    Net::SFTP.start(@host, @user, :password => @password) do |sftp|
      $log.debug "MiqSshUtil::get_file - Copying file #{@host}:#{from} to #{to}." if $log
      data = sftp.download!(from, to)
      $log.debug "MiqSshUtil::get_file - Copying of #{@host}:#{from} to #{to}, complete." if $log
      return data
    end
  end
  
  def exec(cmd, doneStr=nil)
    errBuf = ""
    outBuf = ""
    status = nil
    signal = nil
    
    run_session do |ssh|
      ssh.open_channel do |channel|
        channel.on_data do |channel, data|
          $log.debug "MiqSshUtil::exec - STDOUT: #{data}" if $log
          outBuf << data
          data.each_line { |l| return outBuf if doneStr == l.chomp } unless doneStr.nil?
        end
    
        channel.on_extended_data do |channel, data|
          $log.debug "MiqSshUtil::exec - STDERR: #{data}" if $log
          errBuf << data
        end
    
        channel.on_request('exit-status') do |channel, data| 
          status = data.read_long   
          $log.debug "MiqSshUtil::exec - STATUS: #{status}" if $log
        end
    
        channel.on_request('exit-signal') do |channel, data| 
          signal = data.read_string 
          $log.debug "MiqSshUtil::exec - SIGNAL: #{signal}" if $log
        end
    
        channel.on_eof do |channel| 
          $log.debug "MiqSshUtil::exec - EOF RECEIVED" if $log
        end
    
        channel.on_close do |channel|
          $log.debug "MiqSshUtil::exec - Command: #{cmd}, exit status: #{status}" if $log
          unless signal.nil? || status.zero?
            raise "MiqSshUtil::exec - Command #{cmd}, exited with signal #{signal}" unless signal.nil?
            raise "MiqSshUtil::exec - Command #{cmd}, exited with status #{status}" if errBuf.empty?
            raise "MiqSshUtil::exec - Command #{cmd} failed: #{errBuf}, status: #{status}"
          end
          return outBuf
        end
    
        $log.debug "MiqSshUtil::exec - Command: #{cmd} started." if $log
        channel.exec(cmd) { |channel, success| raise "MiqSshUtil::exec - Could not execute command #{cmd}" unless success }
      end
    end
  end # def exec
  
  def suexec(cmd_str, doneStr=nil)
    errBuf = ""
    outBuf = ""
    prompt = ""
    cmdRX  = ""
    status = nil
    signal = nil
    state  = :initial

    run_session do |ssh|
      temp_cmd_file(cmd_str) do |cmd|
        ssh.open_channel do |channel|

          # now we request a "pty" (i.e. interactive) session so we can send data back and forth if needed.
          # it WILL NOT WORK without this, and it has to be done before any call to exec.
          channel.request_pty(:chars_wide => 256) do |channel, success|
            raise "Could not obtain pty (i.e. an interactive ssh session)" unless success
          end

          channel.on_data do |channel, data|
            $log.debug "MiqSshUtil::suexec - state: [#{state.inspect}] STDOUT: [#{data.hex_dump.chomp}]" if $log
            if state == :prompt
              # Detect the common prompts
              # someuser@somehost ... $  rootuser@somehost ... #  [someuser@somehost ...] $  [rootuser@somehost ...] #
              prompt = data if data =~ /^\[*[\w\-\.]+@[\w\-\.]+.+\]*[\#\$]\s*$/
              outBuf << data
              unless doneStr.nil?
                data.each_line { |l| return outBuf if doneStr == l.chomp }
              end

              if outBuf[-prompt.length, prompt.length] == prompt
                return outBuf[0..(outBuf.length-prompt.length)]
              end
            end

            if state == :command_sent
              cmdRX << data
              state = :prompt if cmdRX == "#{cmd}\r\n"
            end

            if (state == :password_sent)
              prompt << data.lstrip
              if (data.strip =~ /\#/)
                $log.debug "MiqSshUtil::suexec - Superuser Prompt detected: sending command #{cmd}" if $log
                channel.send_data("#{cmd}\n")
                state = :command_sent
              end
            end

            if (state == :initial)
              prompt << data.lstrip
              if (data.strip =~ /[Pp]assword:/)
                prompt = ""
                $log.debug "MiqSshUtil::suexec - Password Prompt detected: sending su password" if $log
                channel.send_data("#{@su_password}\n")
                state = :password_sent
              end
            end

          end

          channel.on_extended_data do |channel, data|
            $log.debug "MiqSshUtil::suexec - STDERR: #{data}" if $log
            errBuf << data
          end

          channel.on_request('exit-status') do |channel, data|
            status = data.read_long
            $log.debug "MiqSshUtil::suexec - STATUS: #{status}" if $log
          end

          channel.on_request('exit-signal') do |channel, data|
            signal = data.read_string
            $log.debug "MiqSshUtil::suexec - SIGNAL: #{signal}" if $log
          end

          channel.on_eof do |channel|
            $log.debug "MiqSshUtil::suexec - EOF RECEIVED" if $log
          end

          channel.on_close do |channel|
            errBuf << prompt if [:initial, :password_sent].include?(state)
            $log.debug "MiqSshUtil::suexec - Command: #{cmd}, exit status: #{status}" if $log
            raise "MiqSshUtil::suexec - Command #{cmd}, exited with signal #{signal}" unless signal.nil?
            unless status.zero?
              raise "MiqSshUtil::suexec - Command #{cmd}, exited with status #{status}" if errBuf.empty?
              raise "MiqSshUtil::suexec - Command #{cmd} failed: #{errBuf}, status: #{status}"
            end
            return outBuf
          end

          $log.debug "MiqSshUtil::suexec - Command: [#{cmd_str}] started." if $log
          su_command = @su_user == 'root' ? "su -l\n" : "su -l #{@su_user}\n"
          channel.exec(su_command) { |channel, success| raise "MiqSshUtil::suexec - Could not execute command #{cmd}" unless success }
        end
      end
    end
  end # suexec

  def temp_cmd_file(cmd)
    temp_remote_script = "/var/tmp/miq-#{Time.now.to_i}.sh"
    self.exec("echo \"#{cmd}\" > #{temp_remote_script}")
    remote_cmd = "chmod 700 #{temp_remote_script}; #{temp_remote_script}; rm -f #{temp_remote_script}"
    yield(remote_cmd)
  end

  def self.shell_with_su(host, remote_user, remote_password, su_user, su_password, options={})
    options[:su_user], options[:su_password] = su_user, su_password
    ssu = MiqSshUtil.new(host, remote_user, remote_password, options)
    yield(ssu, nil)
  end

  def shell_exec(cmd, doneStr=nil, shell=nil)
    return self.exec(cmd, doneStr) if @su_user.nil?
    ret = self.suexec(cmd, doneStr)
    # Remove escape character from the end of the line
    ret.sub!(/\e$/, '')
    ret
  end

  def fileOpen(file_path, perm='r')
    require 'tempfile'
    if block_given?
      Tempfile.open('miqscvmm') do |tf|
        tf.close
        self.get_file(file_path, tf.path)
        File.open(tf.path, perm) {|f| yield(f)}
      end
    else
      tf = Tempfile.open('miqscvmm')
      tf.close
      self.get_file(file_path, tf.path)
      f = File.open(tf.path, perm)
      return f
    end
  end

  def fileExists?(filename)
    self.shell_exec("test -f #{filename}") rescue return false
    true
  end
  
  # This method runs the ssh session and can handle reseting the ssh fingerprint
  # if it does not match and raises an error.
  def run_session
    first_try = true

    # Make a call to ensure we can resolve our own hostname before we continue
    # otherwise the SSH layer will raise an unclear error.
    MiqSockUtil.getFullyQualifiedDomainName

    begin
      Net::SSH.start(@host, @user, @options) do |ssh|
        yield(ssh)
      end
    rescue Net::SSH::HostKeyMismatch => e
      if @remember_host == true && first_try
        # Save fingerprint and try again
        first_try = false
        e.remember_host!
        retry
      else
        # Re-raise error
        raise e
      end
    end
  end
end

class MiqSshUtil

  attr_reader :status, :host

  def initialize(host, user, password, options={})
    @host = host
    @user = user
    @password = password
    @status = 0
    @shell = nil
    @options = {:remember_host=>false, :verbose => :warn, :authentication_prompt_delay=>20}.merge(options)

    # Pull the 'remember_host' key out of the hash because the SSH initializer will complain
    @remember_host = @options.delete(:remember_host)
    @su_user     = @options.delete(:su_user)
    @su_password = @options.delete(:su_password)

    # Set logging to use our default handle if it exists and one was not passed in
    @options[:logger] = $log if $log && !@options.has_key?(:logger)
    @logger = @options.delete(:logger)
    # Logging handle to ssh needs to be an IO object
    @sio = StringIO.new
    @options[:log] = @sio
    
    @auth_prompt_delay = @options.delete(:authentication_prompt_delay)
  end # def initialize

  def cp(from, to)
    Net::SFTP.start(@host, @user, @password, @options) do |s|
      $log.debug "MiqSshUtil::cp - Copying file #{from} to #{@host}:#{to}." if $log
      s.put_file(from, to)
      $log.debug "MiqSshUtil::cp - Copying of #{from} to #{@host}:#{to}, complete." if $log
    end
  end # def cp

  def get_file(from, to)
    Net::SFTP.start(@host, @user, @password, @options) do |s|
      $log.debug "MiqSshUtil::get_file - Copying file #{@host}:#{from} to #{to}." if $log
      s.get_file(from, to)
      $log.debug "MiqSshUtil::get_file - Copying of #{@host}:#{from} to #{to}, complete." if $log
    end
  end

  def exec(cmd, doneStr=nil)
    errBuf = ""
    outBuf = ""

    run_session() do |s|
      $log.debug "MiqSshUtil::exec - Command: #{cmd} started." if $log
      s.process.open(cmd) do |proc|

        proc.on_success do |p|
          $log.debug "MiqSshUtil::exec - Command: #{cmd} succeeded." if $log
        end

        proc.on_failure do |p, status|
          raise "MiqSshUtil::exec - Could not execute command #{cmd}: #{status}"
        end

        proc.on_stderr do |p, data|
          $log.debug "MiqSshUtil::exec - STDERR: #{data}" if $log
          errBuf << data
        end

        proc.on_stdout do |p, data|
          $log.debug "MiqSshUtil::exec - STDOUT: #{data}" if $log
          outBuf << data
          if doneStr
            data.each_line do | l |
              return outBuf if doneStr == l.chomp
            end
          end
        end

        proc.on_exit do |p, status|
          @status = status
          $log.debug "MiqSshUtil::exec - Command: #{cmd}, exit status: #{status}" if $log
          if status != 0
            raise "MiqSshUtil::exec - Command #{cmd}, exited with status #{status}" if errBuf.empty?
            raise "MiqSshUtil::exec - Command #{cmd} failed: #{errBuf}, status: #{status}"
          end
          return outBuf
        end

      end # s.process.open
    end
  end # def exec

  def self.shell_with_su(host, remote_user, remote_password, su_user, su_password, options={})
    ssu = MiqSshUtil.new(host, remote_user, remote_password, options)
    ssu.shell_sync_tty(su_user, su_password) {|ssu_self, shell| yield(ssu_self, shell)}
  end

  def shell_sync_tty(su_user=nil, su_password=nil)
    run_session() do |session|
      shell = session.shell.sync(:pty => true)
      sleep(@auth_prompt_delay)

      unless su_password.nil? || su_password.empty?
        shell.send_data("su -l #{su_user} \n")
        sleep(@auth_prompt_delay)
        shell.send_data("#{su_password}\n")
        sleep(@auth_prompt_delay)
        @shell = shell
      end

      # Make the first command call to run off stdout/stderr messages from the
      # logon and su commands so they are not returned to the commands made after this.
      self.shell_exec("pwd", nil, shell)

      yield(self, shell)
      @shell = nil
      shell.exit
    end
  end

  def shell_exec(cmd, doneStr=nil, shell=@shell)
    if shell
      # Writing to a temp remote script to handle cases where the cmd string is
      #   too long and is truncated.
      temp_remote_script = "/var/tmp/miq-#{Time.now.to_i}.sh"
      self.exec("echo \"#{cmd}\" > #{temp_remote_script}")
      self.exec("chmod 700 #{temp_remote_script}")
      out = shell.send_command(temp_remote_script)
      self.exec("rm -f #{temp_remote_script}")
      @status = out.status
      msg = out.stdout

      # Check if the first output return references the remote script and remove it.
      msgs = msg.split("\n")
      msg = msgs[1..-1].join("\n") if msgs[0].include?(temp_remote_script)

      raise "#{msg}" unless doneStr.nil? || msg.include?(doneStr)
      return msg
    else
      return self.exec(cmd, doneStr)
    end
  end

  # This method runs the ssh session and can handle reseting the ssh fingerprint
  # if it does not match and raises an error.
  def run_session()
    first_try = true

    # Make a call to ensure we can resolve our own hostname before we continue
    # otherwise the SSH layer will raise an unclear error.
    MiqSockUtil.getFullyQualifiedDomainName

    begin
      Net::SSH.start(@host, @user, @password, @options) do |s|
        yield(s)
        log_activity()
      end
    rescue Net::SSH::HostKeyMismatch => e
      if @remember_host == true && first_try
        # Save fingerprint and try again
        first_try = false
        e.remember_host!
        log_activity()
        retry
      else
        log_activity()
        # Re-raise error
        raise e
      end
    rescue
      log_activity()
      raise
    end
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

  def test?(expression)
    begin
      exec("test #{expression}")
      return true
    rescue => err
      return false
    end
  end # def fileExists

  def log_activity()
    @sio.rewind
    @sio.read.each {|line| @logger.send(@options[:verbose], line.chomp)} unless @logger.nil?
    # Clear the StringIO object
    @sio.rewind; @sio.truncate(0)
  end
end # class MiqSshUtil
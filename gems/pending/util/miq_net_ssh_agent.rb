require 'net/ssh'
require 'fileutils'

class MiqNetSshAgent
  attr_reader :pid
  attr_reader :sock

  def initialize(agent_socket, ssh_private_key)
    FileUtils.mkdir_p(File.dirname(agent_socket))
    agent_details = `ssh-agent -a #{agent_socket}`
    @sock         = agent_details.split("=")[1].split(" ")[0].chop
    @pid          = agent_details.split("=")[2].split(" ")[0].chop
    IO.popen({"SSH_AUTH_SOCK" => @sock, "SSH_AGENT_PID" => @pid}, ["ssh-add", "-"], :mode => 'w') do |f|
      f.puts(ssh_private_key)
      if $?.to_i != 0
        raise StandardError, "Couldn't add key to agent"
      end
    end
  end

  def perform_commands(ip, username, commands, _additional_flags = "")
    result = nil
    Net::SSH.start(ip, username, :paranoid => false, :forward_agent => true, :agent_socket_factory => -> { UNIXSocket.open(@sock) }) do |ssh|
      commands.each do |cmd|
        result = ssh_exec!(ssh, cmd)
        result[:last_command] = cmd
        break if result[:exit_status] != 0
      end
    end
    result
  end

  def check_connection(ip, username, sub_ips, additional_flags)
    connection_success = true
    unreachable_hosts  = []
    Net::SSH.start(ip, username, :paranoid => false, :forward_agent => true, :number_of_password_prompts => 0, :agent_socket_factory => -> { UNIXSocket.open(@sock) }) do |ssh|
      sub_ips.each do |sub_ip|
        result = ssh.exec!("ssh #{additional_flags} #{username}@#{sub_ip} echo $?")
        unless result.include? "0\n"
          connection_success = false
          unreachable_hosts << host
        end
      end
    end
    [connection_success, unreachable_hosts]
  end

  private

  def ssh_exec!(ssh, command)
    stdout_data, stderr_data = "", ""
    exit_status, exit_signal = nil, nil

    ssh.open_channel do |channel|
      channel.request_pty
      channel.exec(command) do |_, success|
        raise StandardError, "Command \"#{command}\" was unable to execute" unless success

        channel.on_data do |_, data|
          stdout_data << data
        end

        channel.on_extended_data do |_, _, data|
          stderr_data << data
        end

        channel.on_request("exit-status") do |_, data|
          exit_status = data.read_long
        end

        channel.on_request("exit-signal") do |_, data|
          exit_signal = data.read_long
        end
      end
    end
    ssh.loop
    {
      :stdout      => stdout_data,
      :stderr      => stderr_data,
      :exit_status => exit_status,
      :exit_signal => exit_signal
    }
  end
end

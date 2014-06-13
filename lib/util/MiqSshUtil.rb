$:.push("#{File.dirname(__FILE__)}")

require "rubygems"
require 'net/ssh'
require 'net/ssh/version'  unless defined?(Net::SSH::Version)
require 'net/sftp'
require 'net/sftp/version' unless defined?(Net::SFTP::Version)
require 'stringio'
require 'MiqSockUtil'

# puts "SSH Version: #{Net::SSH::Version::STRING}"
# puts "SFTP Version: #{Net::SFTP::Version::STRING}"

if Net::SSH::Version::MAJOR == 1
  require 'MiqSshUtilV1'
elsif Net::SSH::Version::MAJOR == 2
  require 'MiqSshUtilV2'
else
  raise "MiqSshUtil does not support version #{Net::SSH::Version::STRING} of Net::SSH"
end

if __FILE__ == $0
  require 'log4r'

  #
  # Formatter to output log messages to the console.
  #
  class ConsoleFormatter < Log4r::Formatter
  	def format(event)
  		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
  	end
  end
  $log = Log4r::Logger.new 'toplog'
  Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
  $log.add 'err_console'

  puts "SSH  Version: #{Net::SSH::Version::STRING}"
  puts "SFTP Version: #{Net::SFTP::Version::STRING}"
  
  host          = 'host_for_su_testing'
  userid        = 'user'
  password      = 'secret'
  root_user     = 'root'
  root_password = 'secret'

  # host          = 'host_for_non_su_testing'
  # userid        = 'root'
  # password      = 'secret'
  # root_user     = nil
  # root_password = nil
  
  local_file    = "/Users/myuser/.bash_profile"
  remote_file   = "/tmp/.bash_profile"
  
  if Net::SSH::Version::MAJOR == 1
    MiqSshUtil.shell_with_su(host, userid, password, root_user, root_password) do |ssu, shell|
      puts shell.suexec("id")
      puts ssu.shell_exec("id")
      puts ssu.shell_exec("esxupdate query")
      puts ssu.shell_exec("chkconfig --list")
      puts ssu.shell_exec("rpm -qa --queryformat '%{NAME}|%{VERSION}|%{ARCH}|%{GROUP}|%{RELEASE}|%{SUMMARY}\n'")
      puts ssu.shell_exec("grep PermitRootLogin /etc/ssh/sshd_config")
    end
  else
    s = MiqSshUtil.new(host, userid, password, :su_user => root_user, :su_password => root_password)
    puts s.exec("ls -l /")
    puts s.suexec("id") if userid && root_user && userid != root_user
    puts s.suexec("ls -l /") if userid && root_user && userid != root_user
    s.cp(local_file, remote_file)
    s.get_file(remote_file, "#{local_file}.via_sftp")
    
     MiqSshUtil.shell_with_su(host, userid, password, root_user, root_password) do |ssu, shell|
      puts ssu.suexec("id") if userid && root_user && userid != root_user
      puts ssu.shell_exec("id")
      puts ssu.shell_exec("esxupdate query")
      puts ssu.shell_exec("chkconfig --list")
      puts ssu.shell_exec("rpm -qa --queryformat '%{NAME}|%{VERSION}|%{ARCH}|%{GROUP}|%{RELEASE}|%{SUMMARY}\n'")
      puts ssu.shell_exec("grep PermitRootLogin /etc/ssh/sshd_config")
     end
  end  
end

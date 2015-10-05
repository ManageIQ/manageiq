require_relative '../../bundler_setup'
require 'log4r'
require 'VMwareWebService/MiqVim'
require 'VMwareWebService/MiqVimBroker'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
  def format(event)
    (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
  end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level => Log4r::DEBUG, :formatter => ConsoleFormatter)
$vim_log.add 'err_console'

# $miq_wiredump = true

TARGET_HOST = raise "please define"
hMor = nil

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

miqHost = nil

begin
  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
  puts "API version: #{vim.apiVersion}"

  puts "Host name: #{TARGET_HOST}"
  puts

  # puts "**** Host services:"
  # vim.dumpObj(vim.hostSystems[TARGET_HOST]['config']['service'])
  # puts "****************************************************************"
  # puts

  miqHost = vim.getVimHost(TARGET_HOST)

  # vim.dumpObj(vim.getMoProp(miqHost.hMor))
  # exit

  puts "Host name: #{miqHost.name}"
  puts

  puts "**** configManager:"
  vim.dumpObj(miqHost.configManager)
  puts "****************************************************************"
  puts

  raise "Host has no service system" unless (ss = miqHost.serviceSystem)

  puts "**** Refreshing services..."
  ss.refreshServices
  puts "**** Done."
  puts

  si = ss.serviceInfo

  puts "**** serviceInfo:"
  vim.dumpObj(si)
  puts "****************************************************************"
  puts

  puts "**** SSH service:"
  sshRs = ss.getServicesByFilter('label' => 'SSH Server').first
  unless sshRs
    puts "SSH service not found."
    exit
  end
  vim.dumpObj(sshRs)
  puts "****************************************************************"
  puts

  puts "**** Restarting SSH services..."
  ss.restartService(sshRs.key)
  puts "**** Done."
  puts

  puts "**** SSH service:"
  sshRs = ss.getServicesByFilter('label' => 'SSH Server').first
  unless sshRs
    puts "SSH service not found."
    exit
  end
  vim.dumpObj(sshRs)
  puts "****************************************************************"
  puts

  puts "**** Stopping SSH services..."
  ss.stopService(sshRs.key)
  puts "**** Done."
  puts

  puts "**** SSH service:"
  sshRs = ss.getServicesByFilter('label' => 'SSH Server').first
  unless sshRs
    puts "SSH service not found."
    exit
  end
  vim.dumpObj(sshRs)
  puts "****************************************************************"
  puts

  puts "**** Starting SSH services..."
  ss.startService(sshRs.key)
  puts "**** Done."
  puts

  puts "**** SSH service:"
  sshRs = ss.getServicesByFilter('label' => 'SSH Server').first
  unless sshRs
    puts "SSH service not found."
    exit
  end
  vim.dumpObj(sshRs)
  puts "****************************************************************"
  puts

  puts "**** Setting SSH service policy to off..."
  ss.updateServicePolicy(sshRs.key, "off")
  puts "**** Done."
  puts

  puts "**** SSH service:"
  sshRs = ss.getServicesByFilter('label' => 'SSH Server').first
  unless sshRs
    puts "SSH service not found."
    exit
  end
  vim.dumpObj(sshRs)
  puts "****************************************************************"
  puts

  puts "**** Setting SSH service policy to automatic..."
  ss.updateServicePolicy(sshRs.key, "automatic")
  puts "**** Done."
  puts

  puts "**** SSH service:"
  sshRs = ss.getServicesByFilter('label' => 'SSH Server').first
  unless sshRs
    puts "SSH service not found."
    exit
  end
  vim.dumpObj(sshRs)
  puts "****************************************************************"
  puts
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  miqHost.release if miqHost
  vim.disconnect
end

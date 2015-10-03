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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::OFF, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

# $miq_wiredump = true
TARGET_HOST   = raise "please define"
HOST_USERNAME = ""
HOST_PASSWORD = ""
CLUSTER_NAME  = ""

miqCluster  = nil
miqHost   = nil

broker = MiqVimBroker.new(:client)
vim = broker.getMiqVim(SERVER, USERNAME, PASSWORD)

begin
  
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    puts
    miqHost = vim.getVimHost(TARGET_HOST)
    puts "Got object for host: #{miqHost.name}"
  
    unless miqHost.shutdownSupported?
      puts "Host does not support shutdown"
      exit
    end
  
    puts
    puts "Shutting down host..."
    miqHost.shutdownHost
    puts "done."
  

rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
  miqCluster.release if miqCluster
  vim.disconnect
end

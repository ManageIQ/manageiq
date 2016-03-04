USE_BROKER = true

require_relative '../../bundler_setup'
require 'VMwareWebService/MiqVimBroker'
require 'VMwareWebService/MiqVim'
require 'util/extensions/miq-hash'
require 'util/vmdb-logger'

trap("INT") { exit }

VC_ACCESSORS = [
  [:dataStoresByMor, :storage],
  [:hostSystemsByMor, :host],
  [:virtualMachinesByMor, :vm],
  [:datacentersByMor, :dc],
  [:foldersByMor, :folder],
  [:clusterComputeResourcesByMor, :cluster],
  [:computeResourcesByMor, :host_res],
  [:resourcePoolsByMor, :rp],
]

$vim_log = VMDBLogger.new("./ems_refresh_test.log") unless USE_BROKER

begin
  loop do
    vc_data = Hash.new { |h, k| h[k] = {} }

    begin

      if USE_BROKER
        puts "Connecting with broker."
        broker = MiqVimBroker.new(:client)
        vim = broker.getMiqVim(SERVER, USERNAME, PASSWORD)
      else
        puts "Connecting without broker."
        vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
      end

      puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
      puts "API version: #{vim.apiVersion}"
      puts

      puts "Retrieving inventory..."
      VC_ACCESSORS.each do |acc, type|
        puts "  Retrieving #{type}"
        vc_data[type] = vim.send(acc)
      end

      unless vc_data[:host].nil?
        vc_data[:host].each_key do |mor|
          puts "  Retrieving host scsi data for host mor [#{mor}]"
          begin
            vim_host = vim.getVimHostByMor(mor)
            sd = vim_host.storageDevice
            vc_data.store_path(mor, 'config', 'storageDevice', sd.fetch_path('config', 'storageDevice')) unless sd.nil?
          ensure
            vim_host.release if vim_host rescue nil
          end
        end
      end
      puts "Retrieving inventory...Complete"

    ensure
      puts "Disconnecting"
      vim.disconnect if vim rescue nil
      vim = nil
    end

    puts "Pretending to do work with the data"
    puts
    sleep 0.5
  end

rescue => err
  puts err
  puts err.class.to_s
  puts err.backtrace.join("\n")
end

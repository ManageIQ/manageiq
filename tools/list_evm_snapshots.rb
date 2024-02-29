#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'rubygems'
require 'VMwareWebService/MiqVim'

if ARGV.length != 1
  warn "Usage: #{$0} ems_name"
  exit 1
end

ems_name = ARGV[0]
# server    = ARGV[0]
# username  = ARGV[1]
# password  = ARGV[2]

begin
  ems = ExtManagementSystem.find_by(:name => ems_name)

  puts "Connecting to #{ems.hostname}..."
  vim = ems.connect
  puts "Done."

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{vim.isVirtualCenter? ? 'VC' : 'ESX'}"
  puts "API version: #{vim.apiVersion}"
  puts

  puts "VMs with EVM snapshots:"
  vim.virtualMachinesByMor.each_value do |vm|
    miqVm = vim.getVimVmByMor(vm['MOR'])
    if miqVm.hasSnapshot?(MiqVimVm::EVM_SNAPSHOT_NAME)
      puts "\t" + miqVm.name
    end
  end
rescue => err
  puts err
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end

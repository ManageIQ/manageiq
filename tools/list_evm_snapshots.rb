#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'rubygems'
require 'VMwareWebService/MiqVim'

if ARGV.length != 1
  $stderr.puts "Usage: #{$0} ems_name"
  exit 1
end

ems_name  = ARGV[0]
# server    = ARGV[0]
# username  = ARGV[1]
# password  = ARGV[2]

begin
  ems = ExtManagementSystem.find_by(:name => ems_name)
  username, password = ems.auth_user_pwd(:ws)

  puts "Connecting to #{ems.hostname}..."
  vim = MiqVim.new(ems.hostname, username, password)
  puts "Done."

  puts "vim.class: #{vim.class}"
  puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
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
  puts err.to_s
  puts err.backtrace.join("\n")
ensure
  vim.disconnect
end

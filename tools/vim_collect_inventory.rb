#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

require 'optimist'
ARGV.shift if ARGV.first == "--" # Handle when called through script/runner
opts = Optimist.options do
  opt :ip,     "IP address", :type => :string, :required => true
  opt :user,   "User Name",  :type => :string, :required => true
  opt :pass,   "Password",   :type => :string, :required => true

  opt :bypass, "Bypass broker usage", :type => :boolean
  opt :dir,    "Output directory",    :default => "."
end
Optimist.die :ip, "is an invalid format" unless /^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}$/.match?(opts[:ip])

def process(accessor, dir)
  puts "Reading #{accessor}..."
  data = yield
  puts "Writing #{accessor}..."
  File.open(File.join(dir, "#{accessor}.yml"), "w") { |f| f.write(data.to_yaml(:SortKeys => true)) }
  data
end

VC_ACCESSORS = [
  [:dataStoresByMor,              :storage],
  [:hostSystemsByMor,             :host],
  [:virtualMachinesByMor,         :vm],
  [:datacentersByMor,             :dc],
  [:foldersByMor,                 :folder],
  [:clusterComputeResourcesByMor, :cluster],
  [:computeResourcesByMor,        :host_res],
  [:resourcePoolsByMor,           :rp],
]

dir = File.expand_path(File.join(opts[:dir], "miq_vim_inventory"))
Dir.mkdir(dir) unless File.directory?(dir)
puts "Output in #{dir}"

begin
  require 'VMwareWebService/MiqVim'

  vim = MiqVim.new(:server => opts[:ip], :username => opts[:user], :password => opts[:pass])
  VC_ACCESSORS.each do |accessor, _type|
    process(accessor, dir) { vim.send(accessor) }
  end

  process(:storageDevice, dir) do
    data = {}
    vim.hostSystemsByMor.keys.each do |host_mor|
      begin
        vim_host = vim.getVimHostByMor(host_mor)
        data[host_mor] = vim_host.storageDevice
      ensure
        vim_host.release if vim_host rescue nil
      end
    end
    data
  end

  process(:getAllCustomizationSpecs, dir) do
    begin
      vim_csm = vim.getVimCustomizationSpecManager
      vim_csm.getAllCustomizationSpecs
    rescue RuntimeError => err
      raise unless err.message.include?("not supported on this system")

      []
    ensure
      vim_csm.release if vim_csm rescue nil
    end
  end
ensure
  vim.release unless vim.nil? rescue nil
end

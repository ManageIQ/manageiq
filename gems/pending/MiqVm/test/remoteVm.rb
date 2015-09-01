require_relative '../../bundler_setup'
require 'ostruct'
require 'log4r'
require 'MiqVm/MiqVm'
require 'VmwareWebService/MiqVim'

class ConsoleFormatter < Log4r::Formatter
  def format(event)
    (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
  end
end

SERVER        = raise "please define SERVER"
PORT          = 443
DOMAIN        = raise "please define DOMAIN"
USERNAME      = raise "please define USERNAME"
PASSWORD      = raise "please define PASSWORD"
TARGET_VM     = raise "please define TARGET_VM"

toplog = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level => Log4r::INFO, :formatter => ConsoleFormatter)
toplog.add 'err_console'
$vim_log = $log = toplog if $log.nil?

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
  vim_vm = vim.getVimVmByFilter("config.name" => TARGET_VM)

  unless vim_vm
    puts "VM: #{TARGET_VM} not found"
    vim.disconnect
    exit
  end

  vmx = vim_vm.dsPath.to_s
  puts "Found target VM: #{TARGET_VM}, VMX = #{vmx}"

  ost = OpenStruct.new
  ost.miqVim = vim

  vm = MiqVm.new(vmx, ost)

  vm.rootTrees.each do | fs |
    puts "*** Found root tree for #{fs.guestOS}"
    puts "Listing files in #{fs.pwd} directory:"
    fs.dirEntries.each { |de| puts "\t#{de}" }
    puts
  end

  CATEGORIES	= %w(accounts services software system)
  CATEGORIES.each do |cat|
    puts "Extracting: #{cat}:"
    xml = vm.extract(cat)
    xml.write($stdout, 4)
    puts
  end

  vm.unmount

  vim.disconnect
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
end

base_dir = "/miq"

initStr = ENV.fetch("MIQ_INIT_STR", nil).unpack('m').join
ENV["MIQ_INIT_STR"] = "XXXX"
$: << "#{base_dir}/lib/encryption"

eval(initStr)
require "MiqLoad"

$0 = ENV.fetch("MIQ_EXE_NAME", $0).chomp(".exe")
script_dir = File.dirname(ENV.fetch("MIQ_EXE_PATH", nil))

load "/miq/lib/WriteVm/vmAutomate.rb"

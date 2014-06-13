base_dir = "/miq"

initStr = ENV.fetch("MIQ_INIT_STR", nil).unpack('m').join
ENV["MIQ_INIT_STR"] = "XXXX"
$: << "#{base_dir}/lib/encryption"

#
# Ruby 1.9 require_relative doesn't work with eval.
#
module Kernel
	def require_relative(path)
		require File.join(File.dirname(caller[0]), path.to_str)
	end
end

eval(initStr)
require "MiqLoad"

$0 = ENV.fetch("MIQ_EXE_NAME", $0).chomp(".exe")
script_dir = File.dirname(ENV.fetch("MIQ_EXE_PATH", nil))

load "/miq/lib/ec2Extract/ec2_queue_extract.rb"

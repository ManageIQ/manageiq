initStr = ENV.fetch("MIQ_INIT_STR", nil).unpack('m').join
ENV["MIQ_INIT_STR"] = "XXXX"
$: << "#{File.dirname(__FILE__)}/lib/encryption"
eval(initStr)
require "MiqLoad"
$0 = 'miqhost'
require "#{File.dirname(__FILE__)}/host/miqhost/miqhost"

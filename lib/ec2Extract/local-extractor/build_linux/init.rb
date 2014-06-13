initStr = ENV.fetch("MIQ_INIT_STR", nil).unpack('m').join
ENV["MIQ_INIT_STR"] = "XXXX"

baseDir = File.dirname(__FILE__)

$: << "#{baseDir}/lib/encryption"

cwd = Dir.pwd
Dir.chdir(baseDir)
`ln -s libcrypto.so.0.9.7a libcrypto.so.4`
`ln -s libssl.so.0.9.7a libssl.so.4`
`ln -s libcom_err.so.2.0 libcom_err.so.3`

Dir.chdir(cwd)

eval(initStr)
require "MiqLoad"

$0 = ENV.fetch("MIQ_EXE_NAME", $0).chomp(".exe")
script_dir = File.dirname(ENV.fetch("MIQ_EXE_PATH", nil))

load "#{File.dirname(__FILE__)}/lib/ec2Extract/local-extractor/local-extractor.rb"

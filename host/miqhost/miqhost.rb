require_relative '../bundler_setup'

$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../../lib")
$:.push("#{File.dirname(__FILE__)}/../../lib/util")

require 'active_support/all'
require 'nokogiri'
require 'miq-soap4r'
require 'net/https'
require 'soap/rpc/httpserver'
require 'webrick/https'
require 'expose_services'
require 'MiqHostConfig'
require 'MiqThreadCtl'
require 'miq-logger'
require 'PlatformConfig'
require 'MiqHostWebServer'

#
# Environment variables set by the Ruby self extractor.
#
$0          = ENV.fetch("MIQ_EXE_NAME", $0)     # name of the command being executed
$miqExePath = ENV.fetch("MIQ_EXE_PATH", nil)    # full path to the executable file
$miqExtDir  = ENV.fetch("MIQ_EXT_DIR", nil)     # directory where the extracted files reside

#
# Read configuration and process args.
#
miqHC = MiqHostConfig.new
miqHC.parse

#
# The miqhost configuration, as defined by the defaluts, config file and command line args.
#
$miqHostCfg = miqHC.hostConfig

# Start logging
$log = MIQLogger.get_log($miqHostCfg, __FILE__)

# Validate config parms
miqHC.validateConfig()
pc = PlatformConfig.new($miqHostCfg)
$log.addPostRollEvent(:host_check, true) {pc.host_check}
$miqHostCfg.capabilities = pc.capabilities
pc.starting

# Create webserver
begin
  $miqHostServer = MiqWebServer.create_webserver($miqHostCfg, Manageiq::ExposeServices)
  $log.info "MAIN: $miqHostServer.object_id = #{$miqHostServer.object_id}"

  # Start the server and block until shutdown is called
  $miqHostServer.start

  # Wait for the WebServer servant object to shutdown before exiting.
  $miqHostServer.wait_servant()
rescue => err
  $log.error "Miqhost: #{err}"
  exit(8)
ensure
  $log.info "Miqhost: Shutdown complete."
end

exit(0)

require File.expand_path("../../../config/environment", __dir__)
require "workers/evm_server"

EvmServer.start

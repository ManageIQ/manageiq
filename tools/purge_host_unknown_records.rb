#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

class HostUnknown < Host; end
HostUnknown.destroy_all

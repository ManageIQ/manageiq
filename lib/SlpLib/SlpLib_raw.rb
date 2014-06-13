arch = RUBY_PLATFORM.match(/(.+?)[0-9\.]*$/)[1]
require_relative "lib/#{arch}/SlpLib_raw"

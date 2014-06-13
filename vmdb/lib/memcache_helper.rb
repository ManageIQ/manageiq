module MemcacheHelper
  def self.setup
    require 'memcache'
    require 'memcache_util'
    #require 'cached_model'
    require 'memcache_patch'

    code = <<-EOL
      memcache_options = {
        :compression => true,
        :debug => false,
        :namespace => 'MIQ:VMDB',
        :readonly => false,
        :urlencode => false,
      }

      memcache_server = VMDB::Config.new("vmdb").config[:session][:memcache_server]
      memcache_server ||= "127.0.0.1:11211"
      CACHE = MemCache.new(memcache_server, memcache_options)
    EOL
    eval(code, TOPLEVEL_BINDING)

    ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS.merge!({ 'cache' => CACHE })
  end
end

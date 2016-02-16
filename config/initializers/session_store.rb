if ENV['RAILS_USE_MEMORY_STORE'] || (!Rails.env.development? && !Rails.env.production?)
  Vmdb::Application.config.session_store :memory_store
else
  session_store =
    case Settings.server.session_store
    when "sql"    then :active_record_store
    when "memory" then :memory_store
    when "cache"  then :mem_cache_store
    end

  session_options = {}
  if MiqEnvironment::Command.is_appliance?
    session_options[:secure]   = true
    session_options[:httponly] = true
  end

  if session_store == :mem_cache_store
    require 'dalli'
    session_options = session_options.merge(
      :cache        => Dalli::Client.new(Settings.session.memcache_server, :namespace => "MIQ:VMDB"),
      :expire_after => 24.hours,
      :key          => "_vmdb_session",
    )

    require 'rack/session/dalli'
    Rack::Session::Dalli.prepend Module.new {
      # As we monkey-patch marshal to support autoloading, Dalli can
      # cause a load to occur. Consequently, we need to manage things
      # carefully to prevent a deadlock between the Rails Interlock and
      # Dalli's own exclusive lock.
      def with_lock(*args)
        ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
          super(*args) do
            ActiveSupport::Dependencies.interlock.running do
              yield
            end
          end
        end
      end
    }
  end

  Vmdb::Application.config.session_store session_store, session_options
  msg = "Using session_store: #{Vmdb::Application.config.session_store}"
  $log.info("MIQ(SessionStore) #{msg}")
  puts "** #{msg}" unless Rails.env.production?
end

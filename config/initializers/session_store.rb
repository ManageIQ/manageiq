session_store   = :memory_store if ENV['RAILS_USE_MEMORY_STORE']
session_store ||= :memory_store if !Rails.env.development? && !Rails.env.production?
session_store ||= case Settings.server.session_store
                  when "sql"    then :active_record_store
                  when "memory" then :memory_store
                  when "cache"  then :mem_cache_store
                  end

ManageIQ::Session.store = session_store

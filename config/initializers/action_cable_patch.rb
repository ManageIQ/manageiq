if Gem::Version.new(ActionCable::VERSION::STRING) < Gem::Version.new("5.0.1")
  ActiveSupport.on_load(:action_cable) do
    require 'action_cable/subscription_adapter/postgresql'
    ActionCable::SubscriptionAdapter::PostgreSQL.class_eval do
      def new_connection
        ar_conn = ActiveRecord::Base.connection_pool.checkout
        ActiveRecord::Base.connection_pool.remove ar_conn

        pg_conn = ar_conn.raw_connection

        unless pg_conn.is_a?(PG::Connection)
          raise 'ActiveRecord database must be Postgres in order to use the Postgres ActionCable storage adapter'
        end

        yield pg_conn
      end
    end

    ActionCable::SubscriptionAdapter::PostgreSQL::Listener.class_eval do
      def listen
        @adapter.new_connection do |pg_conn|
          catch :shutdown do
            loop do
              until @queue.empty?
                action, channel, callback = @queue.pop(true)

                case action
                when :listen
                  pg_conn.exec("LISTEN #{pg_conn.escape_identifier channel}")
                  @event_loop.post(&callback) if callback
                when :unlisten
                  pg_conn.exec("UNLISTEN #{pg_conn.escape_identifier channel}")
                when :shutdown
                  throw :shutdown
                end
              end

              pg_conn.wait_for_notify(1) do |chan, pid, message|
                broadcast(chan, message)
              end
            end
          end
        end
      end
    end
  end
elsif Rails.env.development?
  errstr = "ActionCable version is 5.0.1 or newer, please see if we still need this patch: #{__FILE__}!"
  # Display errors in both development.log and STDOUT
  Rails.logger.warn(errstr)
  warn(errstr)
end

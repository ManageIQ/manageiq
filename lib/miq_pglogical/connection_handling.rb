class MiqPglogical
  module ConnectionHandling
    extend ActiveSupport::Concern

    included do
      delegate :logical_replication_supported?, :to => :class
    end

    module ClassMethods
      def logical_replication_supported?
        return @logical_replication_supported if defined?(@logical_replication_supported)

        is_superuser = ActiveRecord::Base.connection.select_value("SELECT usesuper FROM pg_user WHERE usename = CURRENT_USER")
        unless is_superuser
          warn_bookends = ["\e[33m", "\e[0m"]
          msg = "WARNING: Current user is NOT a superuser, logical replication will not function."
          if $stderr.tty?
            warn(warn_bookends.join(msg))
          else
            warn msg
          end
          _log.warn msg
        end

        @logical_replication_supported = is_superuser
      end

      def with_connection_error_handling
        retry_attempted ||= false
        if logical_replication_supported?
          yield
        else
          # Silently do no harm since logical replication is not supported.
          nil
        end
      rescue PG::ConnectionBad
        raise if retry_attempted

        pglogical(true)
        retry_attempted = true
        retry
      end

      def pglogical(_refresh = false)
        # TODO: Review if the reasons behind the previous caching / refreshing
        # of the PG::LogicalReplication::Client
        #
        #    @pglogical = nil if refresh
        #    @pglogical ||= PG::LogicalReplication::Client.new(pg_connection)
        #
        # is still relevant as it caused segfaults with rails 6 when the
        # caching was in place.
        PG::LogicalReplication::Client.new(pg_connection)
      end
    end

    def pglogical(refresh = false)
      self.class.pglogical(refresh)
    end
  end
end

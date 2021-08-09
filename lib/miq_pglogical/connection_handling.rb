class MiqPglogical
  module ConnectionHandling
    extend ActiveSupport::Concern

    included do
      delegate :logical_replication_supported?, :to => :class
    end

    module ClassMethods
      def logical_replication_supported?
        return @logical_replication_supported if defined?(@logical_replication_supported)

         is_superuser = ActiveRecord::Base.connection.exec_query("select usesuper from pg_user where usename = CURRENT_USER;", "SQL").first.first == true # first row, first column
         warn "WARNING: Current user is NOT a superuser, logical replication will not function." unless is_superuser
         @logical_replication_supported = is_superuser
      end

      def with_connection_error_handling
        retry_attempted ||= false
        yield
      rescue PG::ConnectionBad
        raise if retry_attempted

        pglogical(true)
        retry_attempted = true
        retry
      end

      def pglogical(refresh = false)
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

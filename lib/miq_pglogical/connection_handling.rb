class MiqPglogical
  module ConnectionHandling
    extend ActiveSupport::Concern

    module ClassMethods
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
        @pglogical = nil if refresh
        @pglogical ||= PG::LogicalReplication::Client.new(pg_connection)
      end
    end

    def pglogical(refresh = false)
      self.class.pglogical(refresh)
    end
  end
end

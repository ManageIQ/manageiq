class AuditEvent < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_mode_and_value
        [:scope, purge_date]
      end

      def purge_date
        ::Settings.audit_events.history.keep_events.to_i_with_method.seconds.ago.utc
      end

      def purge_window_size
        ::Settings.audit_events.history.purge_window_size
      end

      def purge_scope(older_than = nil)
        where(arel_table[:created_on].lt(older_than))
      end
    end
  end
end

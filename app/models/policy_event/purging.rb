class PolicyEvent < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_date
        ::Settings.policy_events.history.keep_policy_events.to_i_with_method.seconds.ago.utc
      end

      def purge_window_size
        ::Settings.policy_events.history.purge_window_size
      end

      def purge_scope(older_than)
        where(arel_table[:timestamp].lt(older_than))
      end

      def purge_associated_records(ids)
        PolicyEventContent.where(:policy_event_id => ids).delete_all
      end
    end
  end
end

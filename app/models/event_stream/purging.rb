class EventStream < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def keep_events
        ::Settings.event_streams.history.keep_events
      end

      def purge_date
        keep = keep_events.to_i_with_method.seconds
        keep = 6.months if keep == 0
        keep.ago.utc
      end

      def purge_window_size
        ::Settings.event_streams.history.purge_window_size
      end

      def purge_scope(older_than)
        where(arel_table[:timestamp].lteq(older_than))
      end
    end
  end
end

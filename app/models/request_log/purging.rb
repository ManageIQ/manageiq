class RequestLog < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_date
        ::Settings.request_logs.history.keep_request_logs.to_i_with_method.seconds.ago.utc
      end

      def purge_window_size
        ::Settings.request_logs.history.purge_window_size
      end

      def purge_scope(older_than)
        where(arel_table[:created_at].lt(older_than))
      end
    end
  end
end

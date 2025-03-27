class MiqRequest
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_date
        ::Settings.miq_request.history.keep_miq_requests.to_i_with_method.seconds.ago.utc
      end

      def purge_window_size
        ::Settings.miq_request.history.purge_window_size
      end

      def purge_scope(older_than)
        MiqRequest.where(arel_table[:created_on].lt(older_than))
      end

      # this is MiqRequest#destroy hook (defined by relationships on MiqRequest)
      def purge_associated_records(ids)
        RequestLog.where(:resource_id => ids).delete_all
      end

      def purge_method
        :destroy
      end
    end
  end
end

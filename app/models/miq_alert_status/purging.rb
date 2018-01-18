class MiqAlertStatus < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_date
        ::Settings.miq_alert_status.history.keep_miq_alert_statuses.to_i_with_method.seconds.ago.utc
      end

      def purge_window_size
        ::Settings.miq_alert_status.history.purge_window_size
      end

      def purge_scope(older_than)
        where(:ems_id => nil)
        where(arel_table[:timestamp].lt(older_than))
      end
    end
  end
end

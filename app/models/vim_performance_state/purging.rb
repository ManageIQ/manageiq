class VimPerformanceState < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_mode_and_value
        %w[orphaned resource]
      end

      # remove anything where the resource no longer exists AND
      # remove anything older than a certain date
      def purge_timer
        purge_queue(:orphaned, "resource")
        purge_queue(:date, purge_date)
      end

      def purge_window_size
        ::Settings.vim_performance_states.history.purge_window_size
      end

      #
      # By Date
      #

      def purge_date
        ::Settings.vim_performance_states.history.keep_states.to_i_with_method.seconds.ago.utc
      end

      def purge_scope(older_than)
        where(arel_table[:timestamp].lt(older_than))
      end
    end
  end
end

class VimPerformanceState < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_mode_and_value
        %w[orphaned resource]
      end

      # remove anything older than a certain date AND
      # remove anything where the resource no longer exists
      # Use a callback to ensure :date is run first, before
      # :orphaned and not concurrently.
      def purge_timer
        purge_queue(:date, purge_date, {class_name => name, :method_name => :purge_callback})
      end

      def purge_callback(*_unused)
        purge_queue(:orphaned, "resource")
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

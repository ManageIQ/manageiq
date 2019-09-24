class VimPerformanceState < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_mode_and_value
        %w(orphaned resource)
      end

      def purge_window_size
        ::Settings.vim_performance_states.history.purge_window_size
      end
    end
  end
end

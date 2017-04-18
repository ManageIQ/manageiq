module DriftState::Purging
  extend ActiveSupport::Concern
  include PurgingMixin

  module ClassMethods
    def purge_mode_and_value
      value = ::Settings.drift_states.history.keep_drift_states
      mode  = value.number_with_method? ? :date : :remaining
      value = value.to_i_with_method.seconds.ago.utc if mode == :date
      return mode, value
    end

    def purge_window_size
      ::Settings.drift_states.history.purge_window_size
    end

    def purge_count(mode, value)
      send("purge_count_by_#{mode}", value)
    end

    # @param mode [:date, :remaining]
    def purge(mode, value, window = nil, &block)
      send("purge_by_#{mode}", value, window, &block)
    end

    private

    #
    # By Remaining
    #

    # @return [Symbol, Array<Symbol>] resource that is referenced by this table.
    def purge_remaining_foreign_key
      [:resource_type, :resource_id]
    end

    #
    # By Date
    #

    def purge_scope(older_than)
      where(arel_table[:timestamp].lt(older_than))
    end
  end
end

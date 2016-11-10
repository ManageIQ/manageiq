module MiqReportResult::Purging
  extend ActiveSupport::Concern
  include PurgingMixin

  module ClassMethods
    def purge_mode_and_value
      value = VMDB::Config.new("vmdb").config.fetch_path(:reporting, :history, :keep_reports)
      mode  = (value.nil? || value.number_with_method?) ? :date : :remaining
      value = (value || 6.months).to_i_with_method.seconds.ago.utc if mode == :date
      return mode, value
    end

    def purge_window_size
      VMDB::Config.new("vmdb").config.fetch_path(:reporting, :history, :purge_window_size) || 100
    end

    def purge_timer
      purge_queue(*purge_mode_and_value)
    end

    def purge_queue(mode, value)
      MiqQueue.put_or_update(
        :class_name  => name,
        :method_name => "purge",
        :role        => "reporting",
        :queue_name  => "reporting"
      ) { |_msg, item| item.merge(:args => [mode, value]) }
    end

    def purge_count(mode, value)
      send("purge_count_by_#{mode}", value)
    end

    def purge(mode, value, window = nil, &block)
      send("purge_by_#{mode}", value, window, &block)
    end

    def purge_associated_records(ids)
      MiqReportResultDetail.where(:miq_report_result_id => ids).delete_all
      BinaryBlob.where(:resource_type => name, :resource_id => ids).destroy_all
    end

    private

    #
    # By Remaining
    #

    # @return [Symbol, Array<Symbol>] resource that is referenced by this table.
    def purge_remaining_foreign_key
      :miq_report_id
    end

    #
    # By Date
    #
    def purge_scope(older_than)
      where(arel_table[:created_on].lt(older_than))
    end
  end
end

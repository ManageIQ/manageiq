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

    def purge_remaining_conditions(report_id, id)
      where(:miq_report_id => report_id).where(arel_table[:id].lt(id))
    end

    def purge_count_by_remaining(remaining)
      purge_counts_for_remaining(remaining).values.sum
    end

    def purge_by_remaining(remaining, window = nil, &block)
      _log.info("Purging report results older than last #{remaining} results...")

      window ||= purge_window_size
      total = 0
      purge_ids_for_remaining(remaining).each do |report_id, id|
        scope = purge_remaining_conditions(report_id, id)
        total += purge_in_batches(scope, window, total, &block)
      end

      _log.info("Purging report results older than last #{remaining} results...Complete - Deleted #{total} records")
      total
    end

    def purge_counts_for_remaining(remaining)
      purge_ids_for_remaining(remaining).each_with_object({}) do |(report_id, id), h|
        h[report_id] = purge_remaining_conditions(report_id, id).count
      end
    end

    # @param remaining [Numeric] the number of reports to keep per report_id
    # for each report_id, keep a fixed number of reports
    # @return [Hash<Numeric,Array<Numeric>>] hash with report_ids and the report_result_ids to be deleted
    def purge_ids_for_remaining(remaining)
      # TODO: in sql, use PARTITION BY and ROW_NUMBER()
      distinct.pluck(:miq_report_id).compact.sort.each_with_object({}) do |report_id, h|
        results      = where(:miq_report_id => report_id).order("id DESC").limit(remaining + 1).pluck(:id)
        h[report_id] = results[-2] if results.length == remaining + 1
      end
    end

    #
    # By Date
    #
    def purge_scope(older_than)
      where(arel_table[:created_on].lt(older_than))
    end
  end
end

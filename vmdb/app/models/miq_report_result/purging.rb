module MiqReportResult::Purging
  extend ActiveSupport::Concern

  module ClassMethods
    def purge_mode_and_value
      value = VMDB::Config.new("vmdb").config.fetch_path(:reporting, :history, :keep_reports)
      value ||= 6.months
      if ActiveSupport::Duration === value
        [:date, value.ago]
      else
        [:remaining, value]
      end
    end

    def purge_window_size
      VMDB::Config.new("vmdb").config.fetch_path(:reporting, :history, :purge_window_size) || 100
    end

    def purge_timer
      purge_queue(*purge_mode_and_value)
    end

    def purge_queue(mode, value)
      MiqQueue.put_or_update(
        :class_name  => self.name,
        :method_name => "purge",
        :role        => "reporting",
        :queue_name  => "reporting"
      ) { |msg, item| item.merge(:args => [mode, value]) }
    end

    def purge_count(mode, value)
      self.send("purge_count_by_#{mode}", value)
    end

    def purge(mode, value, window = nil, &block)
      self.send("purge_by_#{mode}", value, window, &block)
    end

    def purge_associated_records(ids)
      MiqReportResultDetail.delete_all(:miq_report_result_id => ids)
      BinaryBlob.destroy_all(:resource_type => self.name, :resource_id => ids)
    end

    private

    #
    # By Remaining
    #

    def purge_count_by_remaining(remaining)
      purge_counts_for_remaining(remaining).values.sum
    end

    def purge_by_remaining(remaining, window = nil, &block)
      log_header = "MIQ(#{self.name}.purge)"
      $log.info("#{log_header} Purging report results older than last #{remaining} results...")

      window ||= purge_window_size
      total = 0
      purge_ids_for_remaining(remaining).each do |report_id, id|
        conditions = [{:miq_report_id => report_id}, self.arel_table[:id].lt(id)]
        total += purge_in_batches(conditions, window, total, &block)
      end

      $log.info("#{log_header} Purging report results older than last #{remaining} results...Complete - Deleted #{total} records")
    end

    def purge_counts_for_remaining(remaining)
      purge_ids_for_remaining(remaining).each_with_object({}) do |(report_id, id), h|
        h[report_id] = self.where(:miq_report_id => report_id).where(self.arel_table[:id].lt(id)).count
      end
    end

    def purge_ids_for_remaining(remaining)
      # TODO: This can probably be done in a single query using group-bys or subqueries
      self.select("DISTINCT miq_report_id").collect(&:miq_report_id).compact.sort.each_with_object({}) do |report_id, h|
        results      = self.select(:id).where(:miq_report_id => report_id).order("id DESC").limit(remaining + 1)
        h[report_id] = results[-2].id if results.length == remaining + 1
      end
    end

    #
    # By Date
    #

    def purge_count_by_date(older_than)
      conditions = self.arel_table[:created_on].lt(older_than)
      self.where(conditions).count
    end

    def purge_by_date(older_than, window = nil, &block)
      log_header = "MIQ(#{self.name}.purge)"
      $log.info("#{log_header} Purging report results older than [#{older_than}]...")

      window ||= purge_window_size
      conditions = self.arel_table[:created_on].lt(older_than)
      total = purge_in_batches(conditions, window, &block)

      $log.info("#{log_header} Purging report results older than [#{older_than}]...Complete - Deleted #{total} records")
    end

    #
    # Common methods
    #

    def purge_in_batches(conditions, window, total = 0)
      query = self.select(:id).limit(window)
      [conditions].flatten.each { |c| query = query.where(c) }

      until (batch = query.dup.to_a).empty?
        ids = batch.collect(&:id)

        $log.info("MIQ(#{self.name}.purge) Purging #{ids.length} report results.")
        count  = self.delete_all(:id => ids)
        total += count

        purge_associated_records(ids) if self.respond_to?(:purge_associated_records)

        yield(count, total) if block_given?
      end
      total
    end
  end
end

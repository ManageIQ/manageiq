# Common methods for all purgers.
#
# It is expected that the mixee will provide the following methods:
#
#   purge_conditions(older_than): This method will receive a Time object and
#     should construct an ActiveRecord::Relation representing the conditions
#     for purging.  The conditions should only be made up of where clauses.
#
#   purge_date: This method must return the date from which purging should
#     start.  This value is typically obtained from user configuration relative
#     to the current time (e.g. the configuration specifies "6.months" and the
#     date is determined by calling 6.months.ago.utc).
#
#   purge_window_size: This method must return the maximum number of rows to be
#     deleted on each pass of the purger.  It should be chosen to balance speed
#     and memory use, as well as any records that will be deleted in the
#     purge_associated_records method.  This value is typically obtained from
#     user configuration.
#
#   purge_associated_records(ids): This is an optional method which will receive
#     the ids of the records that have just been deleted, and should purge any
#     other records associated with those ids.
module PurgingMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def purge(older_than = nil, window = nil, &block)
      older_than ||= purge_date
      window     ||= purge_window_size
      purge_by_date(older_than, window, &block)
    end

    def purge_count(older_than = nil)
      older_than ||= purge_date
      purge_count_by_date(older_than)
    end

    private

    def purge_count_by_date(older_than)
      purge_conditions(older_than).count
    end

    def purge_by_date(older_than, window, &block)
      log_header = "MIQ(#{name}.purge)"
      $log.info("#{log_header} Purging records older than [#{older_than}]...")
      total = purge_in_batches(purge_conditions(older_than), window, &block)
      $log.info("#{log_header} Purging records older than [#{older_than}]...Complete - Deleted #{total} records")
    end

    def purge_in_batches(conditions, window, total = 0)
      log_header = "MIQ(#{name}.purge)"

      query = conditions.limit(window)

      until (batch_ids = query.pluck(:id)).empty?
        $log.info("#{log_header} Purging #{batch_ids.length} records.")
        count  = delete_all(:id => batch_ids)
        total += count

        purge_associated_records(batch_ids) if respond_to?(:purge_associated_records)

        yield(count, total) if block_given?
      end
      total
    end
  end
end

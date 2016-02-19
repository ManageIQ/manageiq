# Common methods for all purgers.
#
# It is expected that the mixee will provide the following methods:
#
#   purge_scope(older_than): This method will receive a Time object and
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
#   ? can this be auto defined looking at relations and destroy / delete
module PurgingMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def purge(older_than = nil, window = nil, &block)
      purge_by_date(older_than || purge_date, window || purge_window_size, &block)
    end

    def purge_count(older_than = nil)
      purge_count_by_date(older_than || purge_date)
    end

    private

    def purge_count_by_date(older_than)
      purge_scope(older_than).count
    end

    def purge_by_date(older_than, window = nil, &block)
      _log.info("Purging #{table_name.humanize} older than [#{older_than}]...")
      total = purge_in_batches(purge_scope(older_than), window || purge_window_size, &block)
      _log.info("Purging #{table_name.humanize} older than [#{older_than}]...Complete - Deleted #{total} records")
      total
    end

    def purge_in_batches(conditions, window, total = 0, total_limit = nil)
      query = conditions.select(:id).limit(window)
      current_window = window

      loop do
        # nearing the end of our limit
        left_to_delete = total_limit && (total_limit - total)
        if total_limit && left_to_delete < window
          current_window = left_to_delete
          query = query.limit(current_window)
        end

        if respond_to?(:purge_associated_records)
          # pull back ids - will slow performance
          batch_ids = query.pluck(:id)
          break if batch_ids.empty?
          current_window = batch_ids.size
        else
          batch_ids = query
        end

        _log.info("Purging #{current_window} #{table_name.humanize}.")
        count = unscoped.where(:id => batch_ids).delete_all
        break if count == 0
        total += count

        purge_associated_records(batch_ids) if respond_to?(:purge_associated_records)

        yield(count, total) if block_given?
        break if count < window || (total_limit && (total_limit <= total))
      end
      total
    end
  end
end

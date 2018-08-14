module ArRecentRecordCounts
  extend ActiveSupport::Concern

  module ClassMethods
    # Returns a hash of counts by date for the :created_on field, with the
    # date as the key and the count as the value.
    #
    # @param date Maximum number of days to look back. Default is 30.
    # @param group_by Date group to use for collating data. Default is 'day'.
    # @param key_format Date format used for the hash key. Default is Time object.
    # @param date_field Used by query internally. Default is 'created_on'.
    # @param filter Additional fields to add to the filter.
    # @return [Hash] counts per group_by
    #
    # @example recent_record_counts
    #
    #   Vm.recent_record_counts
    #   Vm.recent_record_counts(date: 10.days.ago.utc)
    #   Vm.recent_record_counts(date: 20.days.ago.utc, group_by: 'month')
    #   Vm.recent_record_counts(date: 30.days.ago.utc, key_format: 'YYYY-MM-DD', :ems_id => 1)
    #   Vm.recent_record_counts(date: 40.days.ago.utc, date_field: 'created_at', :ems_id => 8)
    #
    def recent_record_counts(date: 30.days.ago.utc, group_by: 'day', key_format: nil, date_field: 'created_on', **filter)
      query = if key_format
        where("#{date_field} > ?", date).group("to_char(date_trunc('#{group_by}', #{date_field}), '#{key_format}')")
      else
        where("#{date_field} > ?", date).group("date_trunc('#{group_by}', #{date_field})")
      end

      filter.each { |key, value| query = query.where(key => value) if value }

      query.count
    end
  end
end

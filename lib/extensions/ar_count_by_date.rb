module ArCountByDate
  extend ActiveSupport::Concern

  module ClassMethods
    # Returns a hash of counts by date for the :created_on field, with the
    # date as the key and the count as the value.
    #
    # @param date Maximum number of days to look back. Default is 30.
    # @param group_by Date group to use for collating data. Default is 'day'.
    # @param filter Additional fields to add to the filter.
    # @return [Hash] counts per group_by
    #
    # Examples:
    #
    #   Vm.count_by_date                                       # => {'2018-10-01' => 5, '2018-10-02' => 3}
    #   Vm.count_by_date(10.days.ago.utc)                      # => {'2018-10-01' => 5, '2018-10-02' => 1}
    #   Vm.count_by_date(10.days.ago.utc, 'month')             # => {'2018-10-01' => 6}
    #   Vm.count_by_date(10.days.ago.utc, 'day', :ems_id => 1) # => {'2018-10-01' => 4, '2018-10-02' => 1}
    #
    def count_by_date(date = 30.days.ago.utc, group_by = 'day', filter = {})
      query = where("created_on > ?", date).group("date_trunc('#{group_by}', created_on)")
      filter.each{ |key, value| query = query.where(key => value) if value }
      query.size
    end
  end
end

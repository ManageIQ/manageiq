class Chargeback
  class Consumption
    def initialize(start_time, end_time)
      @start_time, @end_time = start_time, end_time
    end

    def consumed_hours_in_interval
      # Why we need this?
      #   1) We cannot charge for hours until the resources existed (vm provisioned in the middle of month)
      #   2) We cannot charge for future hours (i.e. weekly report on Monday, should charge just monday)
      #   3) We cannot charge for hours after the resource has been retired.
      @consumed_hours_in_interval ||= begin
                                        consumed = (consumption_end - consumption_start).round / 1.hour
                                        consumed > 0 ? consumed : 0
                                      end
    end

    def hours_in_month
      # If the interval is monthly, we have use exact number of days in interval (i.e. 28, 29, 30, or 31)
      # othewise (for weekly and daily intervals) we assume month equals to 30 days
      monthly? ? hours_in_interval : (30.days / 1.hour)
    end

    def consumption_start
      [@start_time, born_at].compact.max
    end

    def resource_end_of_life
      if resource.try(:retires_on)
        resource.retires_on
      elsif resource.try(:ems_id).nil?
        resource.try(:updated_on)
      end
    end

    def consumption_end
      [Time.current, @end_time, resource_end_of_life].compact.min
    end

    def report_interval_start
      @start_time
    end

    def report_interval_end
      [Time.current, @end_time].min
    end

    private

    def hours_in_interval
      @hours_in_interval ||= (@end_time - @start_time).round / 1.hour
    end

    def monthly?
      # A heuristic. Is the interval lenght about 30 days?
      (hours_in_interval * 1.hour - 30.days).abs < 3.days
    end

    def born_at
      resource.try(:created_on)
    end
  end
end

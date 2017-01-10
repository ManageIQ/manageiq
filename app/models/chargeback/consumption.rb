class Chargeback
  class Consumption
    def initialize(start_time, end_time)
      @start_time, @end_time = start_time, end_time
    end

    def consumed_hours_in_interval
      # Why we need this?
      #   1) We cannot charge for hours until the resources existed (vm provisioned in the middle of month)
      #   2) We cannot charge for future hours (i.e. weekly report on Monday, should charge just monday)
      @consumed_hours_in_interval ||= begin
                                        consuption_start = [@start_time, resource.try(:created_on)].compact.max
                                        consumption_end = [Time.current, @end_time].min
                                        (consumption_end - consuption_start).round / 1.hour
                                      end
    end

    def hours_in_month
      # If the interval is monthly, we have use exact number of days in interval (i.e. 28, 29, 30, or 31)
      # othewise (for weekly and daily intervals) we assume month equals to 30 days
      monthly? ? hours_in_interval : (1.month / 1.hour)
    end

    private

    def hours_in_interval
      @hours_in_interval ||= (@end_time - @start_time).round / 1.hour
    end

    def monthly?
      # A heuristic. Is the interval lenght about 30 days?
      (hours_in_interval * 1.hour - 1.month).abs < 3.days
    end
  end
end

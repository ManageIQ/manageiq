class Chargeback
  class Consumption
    def initialize(start_time, end_time)
      @start_time, @end_time = start_time, end_time
    end

    def hours_in_interval
      @hours_in_interval ||= (@end_time - @start_time).round / 1.hour
    end
  end
end

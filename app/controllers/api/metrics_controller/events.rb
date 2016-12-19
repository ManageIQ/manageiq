module Api
  class MetricsController
    class Events
      def self.data_for_key(name, _metric_name, starts, ends)
        metrics = []
        hour = starts
        while hour < ends
          range = (hour - 1.hour)..hour
          metrics << {:timestamp => hour, :value => EventStream.where(:event_type => name, :timestamp => range).count}
          hour += 1.hour
        end

        metrics.map { |m| {:timestamp => m[:timestamp].to_i * 1000, :value => m[:value]} }
      end

      def self.metrics
        keys = EventStream.select(:event_type).distinct.map(&:event_type)
        keys.map { |k| {:id => "event/#{k}/count"} }
      end
    end
  end
end

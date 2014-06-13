module ReportFormatter
  # Represents series for a ziya chart
  class ZgraphSeries < Array
    DATA_EFFECTS = {
      :bevel  => 'bevel_data',  :glow => 'glow_data',
      :shadow => 'shadow_data', :blur => 'blur_data'
    }
    def initialize(type = :flat)
      super()
    end

    def push(datum)
      super(datum.merge(DATA_EFFECTS))
    end

    def sum
      reduce(0.0) { |sum, datum| sum + datum[:value].to_f }
    end

    def value_at(index)
      self[index][:value]
    end

    def add_to_value(index, addition)
      self[index][:value] += addition
    end
  end
end

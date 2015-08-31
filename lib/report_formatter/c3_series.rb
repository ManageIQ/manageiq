module ReportFormatter
  class C3Series < Array
    def initialize(type = :flat)
      super()
    end

    def push(datum)
      super(datum)
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

module ReportFormatter
  # Represents series for a jqplot chart
  class JqplotSeries < Array
    def initialize(type = :flat)
      super()
      @type = type
    end

    def push(datum)
      case @type
      when :flat then super(datum[:value])
      when :pie  then super([shorten_label(datum[:tooltip]), datum[:value]])
      end
    end

    def sum
      case @type
      when :flat then reduce(0.0) { |sum, value| sum + value }
      when :pie  then reduce(0.0) { |sum, (_label, value)| sum + value }
      end
    end

    def value_at(index)
      case @type
      when :flat then self[index]
      when :pie  then self[index][1]
      end
    end

    def add_to_value(index, addition)
      case @type
      when :flat then self[index] += addition
      when :pie  then self[index][1] += addition
      end
    end

    def set_to_zero(index)
      case @type
      when :flat then self[index] = 0
      when :pie  then self[index][1] = 0
      end
    end

    private

    def shorten_label(label)
      parts = label.to_s.split(':')
      parts[0] = parts[0].to_s[0, 14]
      parts.join(':')
    end
  end
end

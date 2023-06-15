class MiqQueue < ApplicationRecord
  class Priority
    include Comparable

    MAX    = 0
    HIGH   = 20
    NORMAL = 100
    LOW    = 150
    MIN    = 200

    attr_reader :value
    alias :to_i :value
    alias :id_for_database :value

    def initialize(value)
      @value = value.to_i
      clamp_value!
    end

    def to_s
      @value.to_s
    end

    def <=>(other)
      other.to_i <=> @value # These are "reversed" to allow lower integers to be higher priority
    end

    def ==(other)
      @value == other.to_i
    end

    def higher_than?(other)
      @value < other.to_i
    end

    def lower_than?(other)
      @value > other.to_i
    end

    def raise_priority(by:)
      self.class.new(@value - by)
    end

    def raise_priority!(by:)
      @value -= by
      clamp_value!
    end

    def lower_priority(by:)
      self.class.new(@value + by)
    end

    def lower_priority!(by:)
      @value += by
      clamp_value!
    end

    private def clamp_value!
      @value = MAX if @value < MAX
      @value = MIN if @value > MIN
      @value
    end
  end
end

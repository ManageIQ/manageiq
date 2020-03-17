module ManageIQ
  module Reporting
    module Formatter
      class C3Series < Array
        def initialize(*)
          super()
        end

        def push(datum)
          super(datum)
        end

        def sum
          super { |datum| datum[:value].to_f }
        end

        def value_at(index)
          self[index][:value]
        end

        def add_to_value(index, addition)
          self[index][:value] += addition
        end

        def set_to_zero(index)
          self[index][:value] = 0
        end
      end
    end
  end
end

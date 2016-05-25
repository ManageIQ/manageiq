# this is from https://github.com/rails/arel/pull/435
# this allows sorting and where clauses to work with virtual_attribute columns
if defined?(Arel::Nodes::Grouping)
  module Arel
    module Nodes
      class Grouping
        include Arel::Expressions
        include Arel::AliasPredication
        include Arel::OrderPredications
        include Arel::Math
      end
    end
  end
end

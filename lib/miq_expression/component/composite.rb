class MiqExpression::Component::Composite < MiqExpression::Component::Base
  def self.build(sub_expressions)
    new(sub_expressions.map { |e| MiqExpression::Component.build(e) })
  end

  attr_reader :sub_expressions

  def initialize(sub_expressions)
    @sub_expressions = sub_expressions
  end
end

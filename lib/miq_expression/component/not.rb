class MiqExpression::Component::Not < MiqExpression::Component::Base
  def self.build(sub_expression)
    new(MiqExpression::Component.build(sub_expression))
  end

  attr_reader :sub_expression

  def initialize(sub_expression)
    @sub_expression = sub_expression
  end

  def to_arel(timezone)
    Arel::Nodes::Not.new(sub_expression.to_arel(timezone))
  end
end

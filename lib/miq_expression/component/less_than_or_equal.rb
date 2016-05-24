class MiqExpression::Component::LessThanOrEqual < MiqExpression::Component::Leaf
  def to_arel(_timezone)
    target.lteq(value)
  end
end

class MiqExpression::Component::GreaterThan < MiqExpression::Component::Leaf
  def to_arel(_timezone)
    target.gt(value)
  end
end

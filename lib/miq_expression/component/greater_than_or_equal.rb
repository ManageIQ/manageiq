class MiqExpression::Component::GreaterThanOrEqual < MiqExpression::Component::Leaf
  def to_arel(_timezone)
    target.gteq(value)
  end
end

class MiqExpression::Component::LessThan < MiqExpression::Component::Leaf
  def to_arel(_timezone)
    target.lt(value)
  end
end

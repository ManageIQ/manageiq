class MiqExpression::Component::NotEqual < MiqExpression::Component::Leaf
  def to_arel(_timezone)
    target.not_eq(value)
  end
end

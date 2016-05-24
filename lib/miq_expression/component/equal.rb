class MiqExpression::Component::Equal < MiqExpression::Component::Leaf
  def to_arel(_timezone)
    target.eq(value)
  end
end

class MiqExpression::Component::IsNotNull < MiqExpression::Component::Leaf
  def to_arel(_timezone)
    target.not_eq(nil)
  end
end

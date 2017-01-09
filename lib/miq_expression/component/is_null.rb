class MiqExpression::Component::IsNull < MiqExpression::Component::Leaf
  def to_arel(_timezone)
    target.eq(nil)
  end
end

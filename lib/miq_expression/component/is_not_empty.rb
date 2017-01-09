class MiqExpression::Component::IsNotEmpty < MiqExpression::Component::Leaf
  def to_arel(_timezone)
    arel = target.not_eq(nil)
    arel = arel.and(target.not_eq("")) if target.string?
    arel
  end
end

class MiqExpression::Component::NotLike < MiqExpression::Component::Leaf
  def to_arel(_timezone)
    target.does_not_match("%#{value}%")
  end
end

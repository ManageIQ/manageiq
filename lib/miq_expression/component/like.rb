class MiqExpression::Component::Like < MiqExpression::Component::Leaf
  def to_arel(_timezone)
    target.matches("%#{value}%")
  end
end

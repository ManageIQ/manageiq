module MiqExpression::Component
  TYPES = {
    "!"            => Not,
    "!="           => NotEqual,
    "<"            => LessThan,
    "<="           => LessThanOrEqual,
    "="            => Equal,
    ">"            => GreaterThan,
    ">="           => GreaterThanOrEqual,
    "after"        => After,
    "and"          => And,
    "before"       => Before,
    "contains"     => Contains,
    "ends with"    => EndsWith,
    "equal"        => Equal,
    "from"         => From,
    "includes"     => Like,
    "is empty"     => IsEmpty,
    "is not empty" => IsNotEmpty,
    "is not null"  => IsNotNull,
    "is null"      => IsNull,
    "is"           => Is,
    "like"         => Like,
    "not like"     => NotLike,
    "not"          => Not,
    "or"           => Or,
    "starts with"  => StartsWith
  }.freeze

  def self.for_operator(operator)
    TYPES[operator.downcase] or raise _("operator '%{operator_name}' is not supported") % {:operator_name => operator}
  end

  def self.build(expression)
    operator = expression.keys.first
    for_operator(operator).build(expression[operator])
  end
end

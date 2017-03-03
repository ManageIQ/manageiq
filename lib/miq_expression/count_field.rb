class MiqExpression::CountField < MiqExpression::Target
  REGEX = /
(?<model_name>([[:upper:]][[:alnum:]]*(::)?)+)
\.(?<associations>[a-z_\.]+)
/x

  def self.parse(field)
    count_field = super(field)
    is_plural = suppress(Exception) { count_field.plural? }
    return unless is_plural

    count_field
  end

  def initialize(model, associations)
    super(model, associations, nil)
  end
end

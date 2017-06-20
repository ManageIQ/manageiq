class MiqExpression::Tag < MiqExpression::Target
  REGEX = /
(?<model_name>([[:alnum:]]*(::)?){4})
\.(?<associations>([a-z_]+\.)*)
(?<namespace>\bmanaged|user_tag\b)
-(?<column>[a-z]+[_[:alnum:]]+)
/x

  MANAGED_NAMESPACE      = 'managed'.freeze
  USER_NAMESPACE         = 'user'.freeze

  attr_reader :namespace

  def self.parse(field)
    parsed_params = parse_params(field) || return
    managed = parsed_params[:namespace] == self::MANAGED_NAMESPACE
    new(parsed_params[:model_name], parsed_params[:associations], parsed_params[:column], managed)
  end

  def initialize(model, associations, column, managed = true)
    super(model, associations, column)
    @base_namespace = managed ? MANAGED_NAMESPACE : USER_NAMESPACE
    @namespace = "/#{@base_namespace}/#{column}"
  end

  def numeric?
    false
  end

  def column_type
    :string
  end

  def sub_type
    column_type
  end

  def attribute_supported_by_sql?
    false
  end

  def report_column
    "#{@base_namespace}.#{column}"
  end
end

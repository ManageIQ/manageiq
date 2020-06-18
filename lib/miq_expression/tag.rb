class MiqExpression::Tag < MiqExpression::Target
  REGEX = /
(?<model_name>(?:[[:upper:]][[:alnum:]]*(?:::[[:upper:]][[:alnum:]]*)*)?)
\.?(?<associations>([a-z_]+\.)*)
(?<namespace>\bmanaged|user_tag\b)
-(?<column>[a-z]+[_:[:alnum:]]+)
/x

  MANAGED_NAMESPACE      = 'managed'.freeze
  USER_NAMESPACE         = 'user'.freeze

  attr_reader :namespace, :base_namespace

  def self.parse(field)
    return unless field.include?('managed') || field.include?('user_tag')
    parsed_params = parse_params(field) || return
    managed = parsed_params[:namespace] == self::MANAGED_NAMESPACE
    new(parsed_params[:model_name], parsed_params[:associations], parsed_params[:column], managed)
  end

  def initialize(model, associations, column, managed = true)
    super(model, associations, column)
    @base_namespace = managed ? MANAGED_NAMESPACE : USER_NAMESPACE
    @namespace = "/#{@base_namespace}/#{column}"
  end

  def to_s
    "#{[model, *associations, base_namespace].compact.join(".")}-#{column}"
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

  # this should only be accessed in MiqExpression
  # please avoid using it
  # for tags, the tag tables are joined to the table's id
  def arel_attribute
    target&.arel_attribute("id", arel_table)
  end

  private

  def tag_path
    @namespace
  end
end

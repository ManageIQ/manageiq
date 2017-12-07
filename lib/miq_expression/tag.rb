class MiqExpression::Tag
  REGEX = /
(?<model_name>([[:alnum:]]*(::)?){4})
\.(?<associations>([a-z_]+\.)*)
(?<namespace>\bmanaged|user_tag\b)
-(?<column>[a-z]+[_[:alnum:]]+)
/x

  def self.parse(field)
    parsed_params = parse_params(field) || return
    managed = parsed_params[:namespace] == self::MANAGED_NAMESPACE
    new(parsed_params[:model_name], parsed_params[:associations], parsed_params[:column], managed)
  end

  MANAGED_NAMESPACE      = 'managed'.freeze
  USER_NAMESPACE         = 'user'.freeze

  attr_reader :model, :namespace, :column

  def initialize(model, _associations, column, managed = true)
    @model = model
    @column = column
    @base_namespace = managed ? MANAGED_NAMESPACE : USER_NAMESPACE
    @namespace = "/#{@base_namespace}/#{column}"
  end

  def contains(value)
    ids = model.find_tagged_with(:any => value, :ns => namespace).pluck(:id)
    model.arel_attribute(:id).in(ids)
  end

  def report_column
    "#{@base_namespace}.#{column}"
  end

  def self.parse_params(field)
    match = self::REGEX.match(field) || return
    # convert matches to hash to format
    # {:model_name => 'User', :associations => ...}
    parsed_params = Hash[match.names.map(&:to_sym).zip(match.to_a[1..-1])]
    parsed_params[:model_name] = parsed_params[:model_name].classify.safe_constantize || return
    parsed_params[:associations] = parsed_params[:associations].to_s.split(".")
    parsed_params
  end
end

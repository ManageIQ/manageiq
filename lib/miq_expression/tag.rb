class MiqExpression::Tag
  TAG_REGEX = /
(?<model_name>([[:alnum:]]*(::)?)+)
\.(?<associations>([a-z_]+\.)*)
(?<namespace>\bmanaged|user_tag\b)
-(?<column>[a-z]+[_[:alnum:]]+)
/x

  def self.parse(field)
    match = TAG_REGEX.match(field) || return

    associations = match[:associations].split(".")
    namespace = match[:namespace] == 'user_tag' ? 'user' : match[:namespace]
    new(match[:model_name].classify.safe_constantize, associations, "/#{namespace}/#{match[:column]}")
  end

  attr_reader :model, :associations, :namespace

  def initialize(model, associations, namespace)
    @model = model
    @associations = associations
    @namespace = namespace
  end

  def contains(value)
    ids = model.find_tagged_with(:any => value, :ns => namespace).pluck(:id)
    model.arel_attribute(:id).in(ids)
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

  def eql?(other)
    other && other.model == model && other.namespace == namespace && other.associations == associations
  end

  alias == eql?
end

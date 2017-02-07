class MiqExpression::Tag
  def self.parse(tag)
    klass, ns = tag.split(".")
    klass, ns = "nil", klass if ns.nil? # support managed-label
    ns = "/" + ns.split("-").join("/")
    ns = ns.sub(/(\/user_tag\/)/, "/user/") # replace with correct namespace for user tags
    new(klass.safe_constantize, ns)
  end

  attr_reader :model, :namespace

  def initialize(model, namespace)
    @model = model
    @namespace = namespace
  end

  def tag?
    true
  end

  def field?
    false
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
    other.try(:model) == model && other.try(:namespace) == namespace
  end
  alias == eql?
end

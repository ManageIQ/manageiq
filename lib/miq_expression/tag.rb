class MiqExpression::Tag
  def self.parse(tag)
    klass, ns = tag.split(".")
    ns = "/" + ns.split("-").join("/")
    ns = ns.sub(/(\/user_tag\/)/, "/user/") # replace with correct namespace for user tags
    new(klass.constantize, ns)
  end

  attr_reader :model, :namespace

  def initialize(model, namespace)
    @model = model
    @namespace = namespace
  end

  def contains(value)
    ids = model.find_tagged_with(:any => value, :ns => namespace).pluck(:id)
    model.arel_attribute(:id).in(ids)
  end
end

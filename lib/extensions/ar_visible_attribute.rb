module ArVisibleAttribute
  extend ActiveSupport::Concern

  included do
    class_attribute :hidden_attribute_names, :default => []
  end

  class_methods do
    # @param [String|Symbol] attribute name of attribute to be hidden from the api and reporting
    # this attribute is accessible to all ruby methods. But it is not advertised.
    # we do this when deprecating an attribute or when introducing an internal attribute
    #
    # NOTE: only use in class definitions, or child classes will be broken
    def hide_attribute(attribute)
      self.hidden_attribute_names += [attribute.to_s]
    end

    # @return Array[String] attribute names that can be advertised in the api and reporting
    # Other attributes are accessible, they are just no longer in our public api (or never were)
    def visible_attribute_names
      attribute_names - hidden_attribute_names
    end
  end
end

module Api
  class OptionsSerializer
    def self.serialize(klass, resource, data = {})
      options = if klass
                  {
                    :attributes         => options_attribute_list(klass.attribute_names -
                                                                  klass.virtual_attribute_names),
                    :virtual_attributes => options_attribute_list(klass.virtual_attribute_names),
                    :relationships      => (klass.reflections.keys |
                                            klass.virtual_reflections.keys.collect(&:to_s)).sort
                  }
                else
                  {:attributes => [], :virtual_attributes => [], :relationships => []}
                end
      options[:subcollections] = Array(CollectionConfig.new[resource].subcollections).sort
      options[:data] = data
      options
    end

    def self.options_attribute_list(attrlist)
      attrlist.sort.select { |attr| !Api.encrypted_attribute?(attr) }
    end
  end
end

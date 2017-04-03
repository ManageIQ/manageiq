module Api
  class OptionsSerializer
    attr_reader :klass, :data, :config

    def initialize(klass, data = {})
      @klass = klass
      @data = data
      @config = CollectionConfig.new
    end

    def serialize
      {
        :attributes         => attributes,
        :virtual_attributes => virtual_attributes,
        :relationships      => relationships,
        :subcollections     => subcollections,
        :data               => data
      }
    end

    private

    def attributes
      return [] unless klass
      options_attribute_list(klass.attribute_names - klass.virtual_attribute_names)
    end

    def virtual_attributes
      return [] unless klass
      options_attribute_list(klass.virtual_attribute_names)
    end

    def relationships
      return [] unless klass
      (klass.reflections.keys | klass.virtual_reflections.keys.collect(&:to_s)).sort
    end

    def subcollections
      return [] unless klass
      Array(config[config.name_for_klass(klass)].subcollections).sort
    end

    def options_attribute_list(attrlist)
      attrlist.sort.select { |attr| !Api.encrypted_attribute?(attr) }
    end
  end
end

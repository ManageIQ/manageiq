module Api
  class OptionsSerializer
    def self.serialize(klass, data = {})
      new(klass, data).serialize
    end

    attr_reader :klass, :data, :config

    def initialize(klass, data = {})
      @klass = klass
      @data = data
      @config = CollectionConfig.new
    end

    def serialize
      resource = config.name_for_klass(klass) if klass
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
      options[:subcollections] = Array(resource ? config[resource].subcollections : nil).sort
      options[:data] = data
      options
    end

    private

    def options_attribute_list(attrlist)
      attrlist.sort.select { |attr| !Api.encrypted_attribute?(attr) }
    end
  end
end

# Module providing attr_accessor_that_yamls method which enables AR::Base objects to be YAML.dump/load with psych and retain the ivars for these attributes
module ActiveRecord
  module AttributeAccessorThatYamls
    extend ActiveSupport::Concern

    def encode_with(coder)
      super
      Array(self.class.attrs_that_yaml).each { |attr| coder[attr.to_s] = instance_variable_get("@#{attr}") }
    end

    def init_with(coder)
      super
      Array(self.class.attrs_that_yaml).each { |attr| instance_variable_set("@#{attr}", coder[attr.to_s]) }
      self
    end

    included do
      class_attribute :attrs_that_yaml
    end

    module ClassMethods
      def attr_accessor_that_yamls(*args)
        module_eval { attr_accessor *args }
        append_to_attrs_that_yaml(*args)
      end

      def attr_reader_that_yamls(*args)
        module_eval { attr_reader *args }
        append_to_attrs_that_yaml(*args)
      end

      def attr_writer_that_yamls(*args)
        module_eval { attr_writer *args }
        append_to_attrs_that_yaml(*args)
      end

      def append_to_attrs_that_yaml(*args)
        self.attrs_that_yaml ||= []
        self.attrs_that_yaml += args
      end
    end
  end
end

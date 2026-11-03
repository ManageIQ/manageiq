# Module providing attr_accessor_that_yamls method which enables AR::Base objects to be YAML.dump/load with psych and retain the ivars for these attributes
module ActiveRecord
  module AttributeAccessorThatYamls
    extend ActiveSupport::Concern

    def encode_with(coder)
      super
      Array(self.class.attrs_that_yaml).each { |attr| coder[attr.to_s] = instance_variable_get(:"@#{attr}") }
    end

    def init_with(coder)
      super
      Array(self.class.attrs_that_yaml).each { |attr| instance_variable_set(:"@#{attr}", coder[attr.to_s]) }
      self
    end

    # Rails 7.1+ marshal_dump (https://www.github.com/rails/rails/pull/47747) only serializes
    # attributes_for_database and cached associations, dropping non-column ivars. Extend the
    # payload so attrs_that_yaml survive Marshal.dump/load.
    # NOTE: super must resolve to AR::Marshalling::Methods#marshal_dump (Rails >= 7.1,
    # marshalling_format_version = 7.1). The 6.1 format removes that method, causing NoMethodError.
    def marshal_dump
      payload = super
      extra = Array(self.class.attrs_that_yaml).each_with_object({}) do |attr, h|
        h[attr] = instance_variable_get(:"@#{attr}")
      end
      payload << extra
    end

    def marshal_load(state)
      *ar_state, extra = state
      super(ar_state)
      extra.each { |attr, val| instance_variable_set(:"@#{attr}", val) } if extra.kind_of?(Hash)
    end

    included do
      class_attribute :attrs_that_yaml
    end

    module ClassMethods
      def attr_accessor_that_yamls(*args)
        module_eval { attr_accessor(*args) }
        append_to_attrs_that_yaml(*args)
      end

      def attr_reader_that_yamls(*args)
        module_eval { attr_reader(*args) }
        append_to_attrs_that_yaml(*args)
      end

      def attr_writer_that_yamls(*args)
        module_eval { attr_writer(*args) }
        append_to_attrs_that_yaml(*args)
      end

      def append_to_attrs_that_yaml(*args)
        self.attrs_that_yaml ||= []
        self.attrs_that_yaml += args
      end
    end
  end
end

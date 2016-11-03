module TreeNode
  class NodeBuilder
    def initialize(object, parent_id, options)
      @object = object
      @parent_id = parent_id
      @options = options
    end

    def self.set_attribute(attribute, value = nil, &block)
      atvar = "@#{attribute}".to_sym

      define_method(attribute) do
        result = instance_variable_get(atvar)

        if result.nil?
          if block_given?
            args = [@object, @options, @parent_id].take(block.arity.abs)
            result = instance_exec(*args, &block)
          else
            result = value
          end
          instance_variable_set(atvar, result)
        end

        result
      end

      equals_method(attribute)
    end

    def self.set_attributes(*attributes, &block)
      attributes.each do |attribute|
        define_method(attribute) do
          result = instance_variable_get("@#{attribute}".to_sym)

          if result.nil?
            results = instance_eval(&block)
            attributes.each_with_index do |local, index|
              instance_variable_set("@#{local}".to_sym, results[index])
              result = results[index] if local == attribute
            end
          end

          result
        end

        equals_method(attribute)
      end
    end

    def self.equals_method(attribute)
      define_method("#{attribute}=".to_sym) do |result|
        instance_variable_set("@#{attribute}".to_sym, result)
      end
    end
  end
end

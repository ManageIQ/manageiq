module MiqAeMethodService
  module MiqAeServiceObjectCommon
    def attributes
      @object.attributes.each_with_object({}) do |(key, value), hash|
        hash[key] = value.kind_of?(MiqAePassword) ? value.to_s : value
      end
    end

    def attributes=(hash)
      @object.attributes = hash
    end

    def [](attr)
      value = @object[attr.downcase]
      value = value.to_s if value.kind_of?(MiqAePassword)
      value
    end

    def []=(attr, value)
      @object[attr.downcase] = value
    end

    # To explicitly override Object#id method, which is spewing deprecation warnings to use Object#object_id
    def id
      @object.try(:id)
    end

    def decrypt(attr)
      MiqAePassword.decrypt_if_password(@object[attr.downcase])
    end

    def current_field_name
      @object.current_field_name
    end

    def current_field_type
      @object.current_field_type
    end

    def current_message
      @object.current_message
    end

    def namespace
      @object.namespace
    end

    def class_name
      @object.klass
    end

    def instance_name
      @object.instance
    end

    def name
      @object.object_name
    end

    def parent
      @object.node_parent ? MiqAeServiceObject.new(@object.node_parent, @service) : nil
    end
  end
end

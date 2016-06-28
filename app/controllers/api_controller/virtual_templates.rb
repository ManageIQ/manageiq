class ApiController
  module VirtualTemplates
    def create_resource_virtual_templates(type, _id, data)
      validate_vendor_present(data)
      klass = collection_class(type)
      virtual_template = klass.create(data)
      if virtual_template.invalid?
        raise BadRequestError,
              "Failed to create a new virtual template - #{virtual_template.errors.full_messages.join(', ')}"
      end
      virtual_template
    end

    private

    def validate_vendor_present(data)
      raise BadRequestError, 'Must specify a vendor for creating a Virtual Template' unless data['vendor']
    end
  end
end

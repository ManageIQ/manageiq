class ApiController
  module VirtualTemplates
    def create_resource_virtual_templates(type, _id, data)
      validate_data(data)
      virtual_template = collection_class(type).create(data)
      if virtual_template.invalid?
        raise BadRequestError,
              "Failed to create a new virtual template - #{virtual_template.errors.full_messages.join(', ')}"
      end
      virtual_template
    end

    private

    def validate_data(data)
      if data.key?('id') || data.key?('href')
        raise BadRequestError, 'Resource id or href should not be specified for creating a new virtual template'
      end
      raise BadRequestError, 'Must specify a vendor for creating a Virtual Template' unless data['vendor']
    end
  end
end

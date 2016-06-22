class ApiController
  module VirtualTemplates
    def create_resource_virtual_templates(_type, _id, data)
      validate_vendor_present(data)
      template = type_from_vendor(data['vendor']).create(data)
      if template.invalid?
        raise BadRequestError, "Failed to create a new virtual template - #{template.errors.full_messages.join(', ')}"
      end
      template
    end

    private

    def validate_vendor_present(data)
      raise BadRequestError, 'Must specify a vendor for creating a Virtual Template' unless data['vendor']
    end

    def type_from_vendor(vendor)
      type = ManageIQ::Providers::CloudManager::VirtualTemplate::TYPES[vendor.to_sym]
      raise BadRequestError, 'Must specify a supported type' unless type
      type.constantize
    end
  end
end

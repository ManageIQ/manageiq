class ApiController
  module VirtualTemplates
    def create_resource_virtual_templates(_type, _id, data)
      validate_vendor_present(data)
      template_name = 'ManageIQ::Providers::' + data['vendor'].capitalize + '::CloudManager::VirtualTemplate'
      const = template_name.constantize
      template = const.new(data)
      if template.invalid?
        raise BadRequestError, "Failed to create a new virtual template - #{template.errors.full_messages.join(', ')}"
      end
      template
    end

    def update_virtual_templates
      aname = parse_action_name
      if aname == 'edit' && !api_user_role_allows?(aname) && update_target_is_api_user?
      else
        update_generic(:virtual_templates)
      end
    end

    private

    def validate_vendor_present(data)
      raise BadRequestError, 'Must specify a vendor for creating a Virtual Template' unless data['vendor']
    end
  end
end

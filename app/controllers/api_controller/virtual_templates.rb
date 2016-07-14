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

    def provision_resource_virtual_templates(type, id, data)
      virtual_template = collection_class(type).find(id)
      validate_provision_request(data)

      version_str             = data['version'] || '1.1'.freeze
      template_fields         = template_fields(virtual_template)
      requester               = data['requester']
      tags                    = virtual_template.tags
      vm_fields               = vm_fields(virtual_template, data)

      MiqProvisionVirtWorkflow.from_ws(version_str, @auth_user_obj, template_fields, vm_fields, requester, tags)
    end

    private

    def validate_data(data)
      if data.key?('id') || data.key?('href')
        raise BadRequestError, 'Resource id or href should not be specified for creating a new virtual template'
      end
      raise BadRequestError, 'Must specify a vendor for creating a Virtual Template' unless data['vendor']
    end

    def validate_provision_request(data)
      raise BadRequestError, 'Requester required' unless data['requester']
      raise BadRequestError, 'VM name required' unless data['vm_name']
    end

    def vm_fields(template, data)
      {
        'placement_availability_zone' => template.availability_zone_id,
        'cloud_network'               => template.cloud_network_id,
        'cloud_subnet'                => template.cloud_subnet_id,
        'instance_type'               => template.flavor_id,
        'vm_name'                     => data['vm_name'],
        'number_of_vms'               => data['number_of_vms']
      }
    end

    def template_fields(template)
      {
        'guid'         => template.guid,
        'name'         => template.name,
        'request_type' => 'template'.freeze
      }
    end
  end
end

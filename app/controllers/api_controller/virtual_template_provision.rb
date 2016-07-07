class ApiController
  module VirtualTemplateProvision
    def provision_create_resource(parent, _type, _id, data)
      validate_provision_request(data)

      version_str             = data['version'] || '1.1'.freeze
      template_fields         = template_fields(parent)
      vm_fields               = vm_fields(parent).merge('vm_name' => data['vm_name'], 'number_of_vms' => data['number_of_vms'])
      requester               = data['requester']
      tags                    = parent.tags

      MiqProvisionVirtWorkflow.from_ws(version_str, @auth_user_obj, template_fields, vm_fields, requester, tags,
                                       nil, nil, nil)
    end

    private

    def validate_provision_request(data)
      raise BadRequestError, 'Requester required' unless data['requester']
      raise BadRequestError, 'VM name required' unless data['vm_name']
    end

    def vm_fields(template)
      {
        'placement_availability_zone' => template.availability_zone_id,
        'cloud_network'               => template.cloud_network_id,
        'cloud_subnet'                => template.cloud_subnet_id,
        'instance_type'               => template.flavor_id
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

class ApiController
  module VirtualTemplateProvision
    def create_resource_virtual_template_provision(type, _id, data)
      virtual_template        = collection_class(type).find(data['template_id'])
      version_str             = data['version'] || '1.1'.freeze
      template_fields         = template_fields(virtual_template)
      vm_fields               = vm_fields(virtual_template).merge('vm_name' => data['vm_name'])
      requester               = data['requester']
      tags                    = virtual_template.tags

      MiqProvisionVirtWorkflow.from_ws(version_str, @auth_user_obj, template_fields, vm_fields, requester, tags,
                                       nil, nil, nil)
    end

    private

    def vm_fields(template)
      {
        'placement_auto'              => false,
        'placement_availability_zone' => template.availability_zone_id,
        'cloud_network'               => template.cloud_network_id,
        'cloud_subnet'                => template.cloud_subnet_id,
        'number_of_vms'               => 1,
        'retirement'                  => 0,
        'boot_disk_size'              => "10.GB",
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

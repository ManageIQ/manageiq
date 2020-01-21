module ServiceTemplateTransformationPlan::ValidateConfigInfo
  extend ActiveSupport::Concern

  def validate_config_info(options)
    self.class.validate_config_info(options)
  end

  module ClassMethods
    def validate_config_info(options)
      config_info = options[:config_info]

      # ------------------------------------------------------------------------
      # TransformationMapping validation
      # ------------------------------------------------------------------------
      mapping = if config_info[:transformation_mapping_id]
                  TransformationMapping.find_by(:id => config_info[:transformation_mapping_id])
                else
                  config_info[:transformation_mapping]
                end
      # mapping.invalid? added as a part of validating migration plan
      raise _('Must provide an existing transformation mapping') if mapping.blank?
      raise _('Transformation mapping was invalid.' + mapping.errors.messages) if mapping.invalid?

      # ------------------------------------------------------------------------
      # ansible playbooks validation
      # ------------------------------------------------------------------------
      pre_service_id  = config_info[:pre_service].try(:id) || config_info[:pre_service_id]
      post_service_id = config_info[:post_service].try(:id) || config_info[:post_service_id]

      # Add as a part of validating migration plan
      # check service_type. Filter type=ServiceTemplateAnsiblePlaybook
      if pre_service_id.present?
        pre_service = ServiceTemplateAnsiblePlaybook.find_by(:id => pre_service_id)
        if pre_service.nil?
          raise _('Premigration service type MUST be "ServiceTemplateAnsiblePlaybook"')
        end
      end

      if post_service_id.present?
        post_service = ServiceTemplateAnsiblePlaybook.find_by(:id => post_service_id)
        if post_service.nil?
          raise _('Postmigration service type MUST be "ServiceTemplateAnsiblePlaybook"')
        end
      end

      # ------------------------------------------------------------------------
      # Get Flavors and SecurityGroups if openstack is the target
      # ------------------------------------------------------------------------
      cloud_tenant        = mapping.transformation_mapping_items.find_by(:destination_type => "CloudTenant")&.destination
      osp_flavors         = cloud_tenant.flavors if cloud_tenant.present?
      osp_security_groups = cloud_tenant.security_groups if cloud_tenant.present?

      # ------------------------------------------------------------------------
      # VMs validation
      # ------------------------------------------------------------------------
      vms = []
      if config_info[:actions]
        vm_objects = VmOrTemplate.where(:id => config_info[:actions].collect { |vm_hash| vm_hash[:vm_id] }.compact).index_by(&:id).stringify_keys
        config_info[:actions].each do |vm_hash|
          vm_obj = vm_objects[vm_hash[:vm_id]] || vm_hash[:vm]
          next if vm_obj.nil?
          # vm_obj.invalid? added as a part of validating migration plan
          raise _("Invalid VM found #{vm_obj.name}") if vm_obj.invalid?

          vm_options = {}
          vm_options[:warm_migration_compatible] = vm_obj.supports_warm_migrate?
          vm_options[:pre_ansible_playbook_service_template_id] = pre_service_id if vm_hash[:pre_service]
          vm_options[:post_ansible_playbook_service_template_id] = post_service_id if vm_hash[:post_service]
          vm_options[:cpu_right_sizing_mode] = vm_hash[:cpu_right_sizing_mode] if vm_hash[:cpu_right_sizing_mode].present?
          vm_options[:memory_right_sizing_mode] = vm_hash[:memory_right_sizing_mode] if vm_hash[:memory_right_sizing_mode].present?
          vm_options[:osp_flavor_id] = vm_hash[:osp_flavor_id] if vm_hash[:osp_flavor_id].present?
          vm_options[:osp_security_group_id] = vm_hash[:osp_security_group_id] if vm_hash[:osp_security_group_id].present?
          vm_options[:warm_migration] = config_info[:warm_migration] || false

          # verify the vm flavor belongs to the openstack tenant/project. added as a part of validating migration plan
          if osp_flavors.present? && vm_options[:osp_flavor_id].present?
            vm_flavor = Flavor.find_by(:id => vm_options[:osp_flavor_id])
            if vm_flavor.present?
              unless osp_flavors.include?(vm_flavor)
                raise _("VM flavor does not belong to the cloud_tenant_flavors")
              end
            else
              raise _("VM flavor not available; can not proceed without it.")
            end
          end

          # verify the security group belong to the openstack tenant/project. added as a part of validating migration plan
          if osp_security_groups.present? && vm_options[:osp_security_group_id].present?
            vm_security_group = SecurityGroup.find_by(:id => vm_options[:osp_security_group_id])
            if vm_security_group.present?
              unless osp_security_groups.include?(vm_security_group)
                raise _("VM security group does not belong to the cloud_tenant_security_groups")
              end
            else
              raise _("VM security group not available; can not proceed without it.")
            end
          end

          vms << {:vm => vm_obj, :options => vm_options}
        end
      end

      raise _('Must select a list of valid vms') if vms.blank?

      {
        :transformation_mapping => mapping,
        :vms                    => vms,
        :provision              => config_info[:provision] || {}
      }
    end
  end
end

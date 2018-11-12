module ServiceTemplateTransformationPlan::ValidateConfigInfo
  extend ActiveSupport::Concern

  def validate_config_info(options)
    self.class.validate_config_info(options)
  end

  module ClassMethods
    def validate_config_info(options)
      config_info = options[:config_info]

      mapping = if config_info[:transformation_mapping_id]
                  TransformationMapping.find(config_info[:transformation_mapping_id])
                else
                  config_info[:transformation_mapping]
                end

      raise _('Must provide an existing transformation mapping') if mapping.blank?

      pre_service_id  = config_info[:pre_service].try(:id) || config_info[:pre_service_id]
      post_service_id = config_info[:post_service].try(:id) || config_info[:post_service_id]

      vms = []
      if config_info[:actions]
        vm_objects = VmOrTemplate.where(:id => config_info[:actions].collect { |vm_hash| vm_hash[:vm_id] }.compact).index_by(&:id).stringify_keys
        config_info[:actions].each do |vm_hash|
          vm_obj = vm_objects[vm_hash[:vm_id]] || vm_hash[:vm]
          next if vm_obj.nil?

          vm_options = {}
          vm_options[:pre_ansible_playbook_service_template_id] = pre_service_id if vm_hash[:pre_service]
          vm_options[:post_ansible_playbook_service_template_id] = post_service_id if vm_hash[:post_service]
          vm_options[:osp_security_group_id] = vm_hash[:osp_security_group_id] if vm_hash[:osp_security_group_id].present?
          vm_options[:osp_flavor_id] = vm_hash[:osp_flavor_id] if vm_hash[:osp_flavor_id].present?
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

module Quadicons
  class VmOrTemplateUrlBuilder < UrlBuilder
    def url
      if context.service_ctrlr_and_vm_view_db?
        context.url_for(args_from_vm_link_attributes_or_blank)
      else
        url_for_record(record, policy_action_for_record)
      end
    end

    def policy_action_for_record
      context.policy_sim? ? "policies" : nil
    end

    def vm_link_attributes
      @link_attrs ||= begin
        if record.kind_of?(ManageIQ::Providers::CloudManager::Vm)
          vm_cloud_attributes.slice(*url_attr_list)
        elsif record.kind_of?(ManageIQ::Providers::InfraManager::Vm)
          vm_infra_attributes.slice(*url_attr_list)
        end
      end
    end

    def vm_cloud_attributes
      attributes = vm_cloud_explorer_accords_attributes
      attributes ||= service_workload_attributes
      attributes
    end

    def vm_infra_attributes
      attributes = vm_infra_explorer_accords_attributes
      attributes ||= service_workload_attributes
      attributes
    end

    def vm_cloud_explorer_accords_attributes
      if context.role_allows?(:feature => "instances_accord") ||
         context.role_allows?(:feature => "instances_filter_accord")

        attributes = {}
        attributes[:link] = true
        attributes[:controller] = "vm_cloud"
        attributes[:action] = "show"
        attributes[:id] = record.id
      end
      attributes
    end

    def vm_infra_explorer_accords_attributes
      if context.role_allows?(:feature => "vandt_accord") ||
         context.role_allows?(:feature => "vms_filter_accord")

        attributes = {}
        attributes[:link] = true
        attributes[:controller] = "vm_infra"
        attributes[:action] = "show"
        attributes[:id] = record.id
      end
      attributes
    end

    def service_workload_attributes
      attributes = {}
      if context.role_allows?(:feature => "vms_instances_filter_accord")
        attributes[:link] = true
        attributes[:controller] = "vm_or_template"
        attributes[:action] = "explorer"
        attributes[:id] = "v-#{record.id}"
      end
      attributes
    end

    private

    def url_attr_list
      %i(controller action id)
    end

    def args_from_vm_link_attributes_or_blank
      if vm_link_attributes.present?
        vm_link_attributes
      else
        ""
      end
    end
  end
end

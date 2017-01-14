module MiqAeMethodService
  class MiqAeServiceMiqProvision < MiqAeServiceMiqProvisionTask
    require_relative "mixins/miq_ae_service_miq_provision_mixin"
    include MiqAeServiceMiqProvisionMixin

    expose :miq_provision_request, :association => true
    expose :vm,                    :association => true
    expose :vm_template,           :association => true
    expose :target_type
    expose :source_type

    expose_eligible_resources :hosts
    expose_eligible_resources :storages
    expose_eligible_resources :folders
    expose_eligible_resources :clusters
    expose_eligible_resources :resource_pools
    expose_eligible_resources :pxe_servers
    expose_eligible_resources :pxe_images
    expose_eligible_resources :windows_images
    expose_eligible_resources :customization_templates
    expose_eligible_resources :iso_images

    def get_network_scope
      object_send(:get_network_scope)
    end

    def get_domain_name
      object_send(:get_domain)
    end

    def get_network_details
      object_send(:get_network_details)
    end

    def set_folder(folder_path)
      object_send(:set_folder, folder_path)
    end

    def statemachine_task_status
      ar_method do
        if %w(finished provisioned).include?(@object.state)
          if @object.status.to_s.downcase == 'error' || @object.vm.nil?
            'error'
          else
            'ok'
          end
        else
          'retry'
        end
      end
    end
  end
end

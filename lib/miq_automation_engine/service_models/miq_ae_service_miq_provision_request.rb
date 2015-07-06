module MiqAeMethodService
  class MiqAeServiceMiqProvisionRequest < MiqAeServiceMiqRequest
    require_relative "mixins/miq_ae_service_miq_provision_mixin"
    include MiqAeServiceMiqProvisionMixin

    expose :miq_request,    :association => true
    expose :miq_provisions, :association => true
    expose :vm_template,    :association => true
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

    def ci_type
      'vm'
    end

    def get_retirement_days
      days = get_option(:retirement)
      return day if days.blank?
      days / ( 60 * 60 * 24 )   # Convert from seconds to days
    end

    def set_folder(folder_path)
      object_send(:set_folder, folder_path)
    end

    def src_vm_id
      object_send(:source_id)
    end
  end
end

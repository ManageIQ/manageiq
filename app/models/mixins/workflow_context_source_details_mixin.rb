module WorkflowContextSourceDetailsMixin
  extend ActiveSupport::Concern

  def workflow_context
    remote_ws_url = MiqRegion.my_region.remote_ws_url
    api_base_url  = URI.join(remote_ws_url, "api")
    evm_owner     = source.evm_owner
    service       = source.service

    source_details = {
      :id      => source.id,
      :name    => source.name,
      :ems_ref => source.ems_ref,
      :href    => URI.join(api_base_url, source.href_slug)
    }

    if evm_owner
      source_details[:owner] = {
        :id     => evm_owner.id,
        :userid => evm_owner.userid,
        :name   => evm_owner.name,
        :email  => evm_owner.email,
        :href   => URI.join(api_base_url, evm_owner.href_slug)
      }
    end

    if service
      source_details[:service] = {
        :id   => service.id,
        :name => service.name,
        :href => URI.join(api_base_url, service.href_slug)
      }
    end

    super.merge(:_object_details => source_details)
  end
end

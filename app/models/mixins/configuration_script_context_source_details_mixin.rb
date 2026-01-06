module ConfigurationScriptContextSourceDetailsMixin
  extend ActiveSupport::Concern

  def configuration_script_context
    remote_ws_url = MiqRegion.my_region.remote_ws_url
    api_base_url  = URI.join(remote_ws_url, "api") if remote_ws_url
    evm_owner     = source.evm_owner
    service       = source.service

    source_details = {
      :id      => source.id,
      :name    => source.name,
      :ems_ref => source.ems_ref
    }
    source_details[:href] = URI.join(api_base_url, source.href_slug).to_s if api_base_url

    if evm_owner
      source_details[:owner] = {
        :id     => evm_owner.id,
        :userid => evm_owner.userid,
        :name   => evm_owner.name,
        :email  => evm_owner.email
      }
      source_details[:owner][:href] = URI.join(api_base_url, evm_owner.href_slug).to_s if api_base_url
    end

    if service
      source_details[:service] = {
        :id   => service.id,
        :name => service.name
      }
      source_details[:service][:href] = URI.join(api_base_url, service.href_slug).to_s if api_base_url
    end

    super.merge(:_object_details => source_details)
  end
end

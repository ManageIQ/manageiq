module Api
  class BaseController
    module Proxy
      def proxy_request?(id)
        return false if id && ApplicationRecord.id_in_current_region?(id)
        region_id = ApplicationRecord.id_to_region(id)
        region = MiqRegion.find_by(:region => region_id)
        subject = "#{@req.subject}/#{@req.subject_id}"
        warn_msg = if region.nil?
                     "Could not find region #{region_id} for #{subject}"
                   elsif region.auth_key_configured?
                     "The remote region #{region_id} for #{subject} is not configured for central administration"
                   elsif region.remote_ws_url.nil?
                     "The remote region #{region_id} for #{subject} does not have a web service address"
                   end
        if warn_msg
          api_log_warn("#{warn_msg}, processing request locally")
          return false
        end
        true
      end

      def proxy_request(id, request_body)
        region = MiqRegion.find_by(:region => ApplicationRecord.id_to_region(id))
        url = region.remote_ws_url
        miq_token = region.api_system_auth_token(@auth_user)

        Proxy::Request.new(url, $api_log).proxy_request(request, request_body, @req.method, @req.fullpath, miq_token)
      rescue => err
        raise BadRequestError, "Failed to proxy request to #{url} - #{err}"
      end

      def render_proxy_request(req)
        head :no_content if req.response.status == 204
        render :json => req.response.body, :status => req.response.status
      end
    end
  end
end

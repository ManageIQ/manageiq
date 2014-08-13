module ApplicationHelper
  module PagingControls
    def paging_controls_url(action_url, more_url_parms = {})
      action_method = action_url.split("/").first
      action_id     = action_url.split("/").last
      url_parms     = more_url_parms

      if action_id
        url_parms[:action] = action_method
        url_parms[:id]     = action_id if is_integer?(action_id)
      else
        url_parms[:action] = action_url
      end

      url_parms[:sb_controller] = params[:sb_controller] if params[:sb_controller]

      url_for(url_parms)
    end
  end
end

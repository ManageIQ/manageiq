module AnsibleExtraVarsMixin
  extend ActiveSupport::Concern

  def manageiq_env(user, miq_group, request_task = nil)
    {
      'api_url'     => api_url,
      'api_token'   => api_token(user),
      'user'        => user.href_slug,
      'group'       => miq_group.href_slug,
      'X_MIQ_Group' => user.current_group.description,
    }.merge(task_url(request_task))
  end

  def manageiq_connection_env(user)
    {
      'url'         => api_url,
      'token'       => api_token(user),
      'X_MIQ_Group' => user.current_group.description
    }
  end

  private

  def api_token(user)
    @api_token ||= Api::UserTokenService.new.generate_token(user.userid, 'api')
  end

  def api_url
    @api_url ||= MiqRegion.my_region.remote_ws_url
  end

  def task_url(request_task)
    request_task ? {'request_task' => "#{request_task.miq_request.href_slug}/#{request_task.href_slug}", 'request' => request_task.miq_request.href_slug} : {}
  end
end

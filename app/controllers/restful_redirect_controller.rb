class RestfulRedirectController < ApplicationController
  def index
    case params[:model]
    when 'MiqRequest'
      redirect_to :controller => 'miq_request', :action => 'show', :id => params[:id]
    else
      redirect_to :controller => 'dashboard', :flash_msg => _("Could not find #{params[:model]}[id=#{params[:id]}]")
    end
  end
end

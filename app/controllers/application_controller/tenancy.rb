module ApplicationController::Tenancy
  extend ActiveSupport::Concern

  included do
    helper_method :current_tenant
    hide_action :set_session_tenant
    hide_action :current_tenant
    hide_action :refresh_session_tenant
  end

  def current_tenant
    # current_user.try(:current_group).try(:tenant) || Tenant.default_tenant
    @current_tenant ||=
     #  Tenant.where(:subdomain => request.subdomains.last).first ||
     #  Tenant.where(:domain => request.domain).first ||
      Tenant.default_tenant
  end

  # NOTE: remove when these session vars are removed
  def set_session_tenant(tenant = current_tenant)
    session[:customer_name] = tenant.try(:name)
    session[:custom_logo]   = tenant.try(:logo?)
    tenant
  end
end

module ApplicationController::Tenancy
  extend ActiveSupport::Concern

  included do
    set_current_tenant_by_subdomain_or_domain(:tenant)
  end

  # NOTE: remove when these session vars are removed
  def set_session_tenant(tenant = current_tenant)
    session[:customer_name] = tenant.try(:company_name)
    session[:vmdb_name]     = tenant.try(:appliance_name)
    session[:custom_logo]   = tenant.try(:logo?)
    tenant
  end
  private :set_session_tenant

  alias_method :refresh_session_tenant, :set_session_tenant
  protected :refresh_session_tenant
end

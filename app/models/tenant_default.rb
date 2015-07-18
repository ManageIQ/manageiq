# Default Tenant stores data in the settings not database
class TenantDefault
  include PaperclipArMixin

  # original code hardcoded logo names
  HARDCODED_LOGO = "custom_logo.png"
  HARDCODED_LOGIN_LOGO = "custom_login_logo.png"

  attr_reader :id # bigint

  def initialize(_options = {})
    @id = 1
  end

  has_attached_file :logo,
                    :url  => "/uploads/#{HARDCODED_LOGO}",
                    :path => ":rails_root/public/uploads/#{HARDCODED_LOGO}"

  has_attached_file :login_logo,
                    :url         => "/uploads/#{HARDCODED_LOGIN_LOGO}",
                    :default_url => ":default_login_logo",
                    :path        => ":rails_root/public/uploads/#{HARDCODED_LOGIN_LOGO}"

  # session[:customer_name]
  def company_name
    settings.fetch_path(:server, :company)
  end

  # session[:vmdb_name]
  def appliance_name
    settings.fetch_path(:server, :name)
  end

  # session[:custom_logo]
  def logo?
    settings.fetch_path(:server, :custom_logo)
  end

  def login_logo?
    settings.fetch_path(:server, :custom_login_logo)
  end

  # @return [Boolean] Is this a default tenant?
  def default?
    true
  end

  # @return [Boolean] Is this a tenant reading out of settings?
  def settings?
    true
  end

  def logo_file_name
    logo? ? HARDCODED_LOGO : nil
  end

  def logo_content_type
    'image/png'
  end

  def login_logo_file_name
    login_logo? ? HARDCODED_LOGIN_LOGO : nil
  end

  def login_logo_content_type
    'image/png'
  end

  alias_method :customer_name, :company_name
  alias_method :vmdb_name, :appliance_name

  private

  def settings
    @vmdb_config ||= VMDB::Config.new("vmdb").config
  end
end

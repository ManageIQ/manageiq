require 'ancestry'

class Tenant < ActiveRecord::Base
  HARDCODED_LOGO = "custom_logo.png"
  HARDCODED_LOGIN_LOGO = "custom_login_logo.png"
  DEFAULT_URL = nil

  default_value_for :company_name, "My Company"
  has_ancestry

  has_many :owned_providers,              :foreign_key => :tenant_owner_id, :class_name => 'Provider'
  has_many :owned_ext_management_systems, :foreign_key => :tenant_owner_id, :class_name => 'ExtManagementSystem'
  has_many :owned_vm_or_templates,        :foreign_key => :tenant_owner_id, :class_name => 'VmOrTemplate'

  has_many :tenant_resources
  has_many :vm_or_templates,
           :through     => :tenant_resources,
           :source      => :resource,
           :source_type => "VmOrTemplate"
  has_many :ext_management_systems,
           :through     => :tenant_resources,
           :source      => :resource,
           :source_type => "ExtManagementSystem"
  has_many :providers,
           :through     => :tenant_resources,
           :source      => :resource,
           :source_type => "Provider"

  has_many :miq_groups, :foreign_key => :tenant_owner_id
  has_many :users, :through => :miq_groups

  # FUTURE: /uploads/tenant/:id/logos/:basename.:extension # may want style
  has_attached_file :logo,
                    :url  => "/uploads/:basename.:extension",
                    :path => ":rails_root/public/uploads/:basename.:extension"

  has_attached_file :login_logo,
                    :url         => "/uploads/:basename.:extension",
                    :default_url => ":default_login_logo",
                    :path        => ":rails_root/public/uploads/:basename.:extension"

  validates :subdomain, :uniqueness => true, :allow_nil => true
  validates :domain,    :uniqueness => true, :allow_nil => true

  # FUTURE: allow more content_types
  validates_attachment_content_type :logo, :content_type => ['image/png']
  validates_attachment_content_type :login_logo, :content_type => ['image/png']

  # FUTURE: this is currently called session[:customer_name]. use this temporarily then remove
  alias_attribute :customer_name, :company_name
  # FUTURE: this is currently called session[:vmdb_name]. use this temporarily then remove
  alias_attribute :vmdb_name, :appliance_name

  before_save :nil_blanks

  def company_name
    tenant_attribute(:company_name, :company)
  end

  def appliance_name
    tenant_attribute(:appliance_name, :name)
  end

  def login_text
    tenant_attribute(:login_text, :custom_login_text)
  end

  def logo_file_name
    tenant_attribute(:logo_file_name, :custom_logo) do |custom_logo|
      custom_logo && HARDCODED_LOGO
    end
  end

  def logo_content_type
    tenant_attribute(:logo_content_type, :custom_logo) do |_custom_logo|
      # fails validation when using custom_logo && "image/png"
      "image/png"
    end
  end

  def login_logo_file_name
    tenant_attribute(:login_logo_file_name, :custom_login_logo) do |custom_logo|
      custom_logo && HARDCODED_LOGIN_LOGO
    end
  end

  def login_logo_content_type
    tenant_attribute(:login_logo_content_type, :custom_login_logo) do |_custom_logo|
      # fails validation when using custom_logo && "image/png"
      "image/png"
    end
  end

  # @return [Boolean] Is this a default tenant?
  def default?
    subdomain == DEFAULT_URL && domain == DEFAULT_URL
  end

  def logo?
    !!logo_file_name
  end

  def login_logo?
    !!login_logo_file_name
  end

  def self.default_tenant
    Tenant.find_by(:subdomain => DEFAULT_URL, :domain => DEFAULT_URL)
  end

  def self.root_tenant
    default_tenant
  end

  def self.seed
    Tenant.create_with(:company_name => nil).find_or_create_by(:subdomain => DEFAULT_URL, :domain => DEFAULT_URL)
  end

  private

  def tenant_attribute(attr_name, setting_name)
    ret = self[attr_name]
    # if the attribute is nil and we are the default tenant
    # then use settings values
    if ret.nil? && default?
      ret = settings.fetch_path(:server, setting_name)
      block_given? ? yield(ret) : ret
    else
      ret
    end
  end

  def nil_blanks
    self.subdomain = nil unless subdomain.present?
    self.domain = nil unless domain.present?

    self.company_name = nil unless company_name.present?
    self.appliance_name = nil unless appliance_name.present?
  end

  def settings
    @vmdb_config ||= VMDB::Config.new("vmdb").config
  end
end

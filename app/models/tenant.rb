require 'ancestry'

class Tenant < ActiveRecord::Base
  HARDCODED_LOGO = "custom_logo.png"
  HARDCODED_LOGIN_LOGO = "custom_login_logo.png"
  DEFAULT_URL = nil

  include ReportableMixin

  default_value_for :name,        "My Company"
  default_value_for :description, "Tenant for My Company"
  default_value_for :divisible,   true
  has_ancestry

  has_many :providers
  has_many :ext_management_systems
  has_many :vm_or_templates
  has_many :service_catalog_templates
  has_many :service_templates

  has_many :tenant_quotas
  has_many :miq_groups
  has_many :users, :through => :miq_groups
  has_many :ae_domains, :dependent => :destroy, :class_name => 'MiqAeDomain'

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
  validate  :validate_only_one_root
  validates :description, :presence => true
  validates :name, :presence => true, :unless => :use_config_for_attributes?
  validates :name, :uniqueness => {:scope => :ancestry, :message => "should be unique per parent" }

  # FUTURE: allow more content_types
  validates_attachment_content_type :logo, :content_type => ['image/png']
  validates_attachment_content_type :login_logo, :content_type => ['image/png']

  scope :all_tenants,  -> { where(:divisible => true) }
  scope :all_projects, -> { where(:divisible => false) }

  virtual_column :parent_name,  :type => :string
  virtual_column :display_type, :type => :string

  before_save :nil_blanks

  def all_subtenants
    self.class.descendants_of(self).where(:divisible => true)
  end

  def all_subprojects
    self.class.descendants_of(self).where(:divisible => false)
  end

  def name
    tenant_attribute(:name, :company)
  end

  def parent_name
    parent.try(:name)
  end

  def display_type
    project? ? "Project" : "Tenant"
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

  def get_quotas
    tenant_quotas.each_with_object({}) do |q, h|
      h[q.name.to_sym] = TenantQuota.quota_definitions[q.name.to_sym].merge(:unit => q.unit, :value => q.value, :format => q.format)
      h
    end.reverse_merge(TenantQuota.quota_definitions)
  end

  def set_quotas(quotas)
    updated_keys = []

    self.class.transaction do
      quotas.each do |name, values|
        next if values[:value].nil?

        q = tenant_quotas.where(:name => name).last || tenant_quotas.build(values.merge(:name => name))
        q.unit ||= q.default_unit
        q.update_attributes!(values)
        updated_keys << name.to_sym
      end
      # Delete any quotas that were not passed in
      TenantQuota.destroy_all(:tenant => self, :name => (TenantQuota.quota_definitions.keys.sort - updated_keys.sort))
      clear_association_cache
    end

    get_quotas
  end

  # @return [Boolean] Is this a default tenant?
  def default?
    root?
  end

  # @return [Boolean] Is this the root tenant?
  def root?
    !parent_id?
  end

  def tenant?
    divisible?
  end

  def project?
    !divisible?
  end

  def logo?
    !!logo_file_name
  end

  def login_logo?
    !!login_logo_file_name
  end

  # The default tenant is the tenant to be used when
  # the url does not map to a known domain or subdomain
  #
  # At this time, urls are not used, so the root tenant is returned
  # @return [Tenant] default tenant
  def self.default_tenant
    root_tenant
  end

  # the root tenant is also referred to as tenant0
  # from this tenant, all tenants are positioned
  #
  # @return [Tenant] the root tenant
  def self.root_tenant
    roots.first
  end

  def self.seed
    Tenant.root_tenant || Tenant.create!(:use_config_for_attributes => true)
  end

  private

  # when a root tenant has an attribute with a nil value,
  #   read the value from the configurations table instead
  #
  # @return the attribute value
  def tenant_attribute(attr_name, setting_name)
    if use_config_for_attributes?
      ret = get_vmdb_config.fetch_path(:server, setting_name)
      block_given? ? yield(ret) : ret
    else
      self[attr_name]
    end
  end

  def nil_blanks
    self.subdomain = nil unless subdomain.present?
    self.domain = nil unless domain.present?

    self.name = nil unless name.present?
  end

  def get_vmdb_config
    @vmdb_config ||= VMDB::Config.new("vmdb").config
  end

  # validates that there is only one tree
  def validate_only_one_root
    if !(parent_id || parent)
      root = self.class.root_tenant
      errors.add(:parent, "required") if root && root != self
    end
  end
end

class TenantQuota < ActiveRecord::Base
  belongs_to :tenant

  QUOTA_BASE = {
    :cpu_allocated => {
      :unit          => :mhz,
      :format        => :mhz,
      :text_modifier => "Mhz".freeze
    },
    :mem_allocated => {
      :unit          => :bytes,
      :format        => :gigabytes_human,
      :text_modifier => "GB".freeze
    },
    :storage_allocated => {
      :unit          => :bytes,
      :format        => :gigabytes_human,
      :text_modifier => "GB".freeze
    },
    :vms_allocated => {
      :unit          => :fixnum,
      :format        => :general_number_precision_0,
      :text_modifier => "Count".freeze
    },
    :templates_allocated => {
      :unit          => :fixnum,
      :format        => :general_number_precision_0,
      :text_modifier => "Count".freeze
    }
  }

  NAMES = QUOTA_BASE.keys.map(&:to_s)

  validates :name, :inclusion => {:in => NAMES}
  validates :unit, :value, :presence => true

  before_validation(:on => :create) do
    self.unit = default_unit unless unit.present?
  end

  def self.quota_definitions
    @quota_definitions ||= QUOTA_BASE.each_with_object({}) do |(name, value), h|
      h[name] = value.merge(:description => I18n.t("dictionary.tenants.#{name}"), :value => nil)
    end
  end

  def quota_hash
    self.class.quota_definitions[name.to_sym].merge(:unit => unit, :value => value, :format => format) # attributes
  end

  def format
    self.class.quota_definitions.fetch_path(name.to_sym, :format).to_s
  end

  def default_unit
    self.class.quota_definitions.fetch_path(name.to_sym, :unit).to_s
  end
end

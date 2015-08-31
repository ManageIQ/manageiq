class TenantQuota < ActiveRecord::Base
  belongs_to :tenant

  QUOTA_BASE = {
    :cpu_allocated => {
      :unit          => :mhz,
      :format        => :mhz,
      :text_modifier => "Mhz"
    },
    :mem_allocated => {
      :unit          => :bytes,
      :format        => :gigabytes_human,
      :text_modifier => "GB"
    },
    :storage_allocated => {
      :unit          => :bytes,
      :format        => :gigabytes_human,
      :text_modifier => "GB"
    },
    :vms_allocated => {
      :unit          => :fixnum,
      :format        => :general_number_precision_0,
      :text_modifier => "Count"
    },
    :templates_allocated => {
      :unit          => :fixnum,
      :format        => :general_number_precision_0,
      :text_modifier => "Count"
    }
  }

  NAMES = QUOTA_BASE.stringify_keys

  validates :name, :inclusion => {:in => NAMES}
  validates :unit, :value, :presence => true

  def self.quota_definitions
    return @quota_definitions if @quota_definitions

    @quota_definitions = QUOTA_BASE.each_with_object({}) do |q, h|
      name, value = q
      h[name] = value.merge(:description => I18n.t("dictionary.tenants.#{name}"), :value => nil)
      h
    end
  end

  def format
    self.class.quota_definitions.fetch_path(name.to_sym, :format).to_s
  end

  def default_unit
    self.class.quota_definitions.fetch_path(name.to_sym, :unit).to_s
  end
end

class TenantQuota < ActiveRecord::Base
  belongs_to :tenant

  QUOTAS = {
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

  NAMES = QUOTAS.stringify_keys

  validates :name, :inclusion => {:in => NAMES}
  validates :unit, :value, :presence => true

  def self.available
    return @available if @available

    @available = QUOTAS.each_with_object({}) do |q, h|
      name, value = q
      h[name] = value.merge(:description => I18n.t("dictionary.tenants.#{name}"), :value => nil)
      h
    end
  end

  def self.get(tenant)
    tenant.tenant_quotas.each_with_object({}) do |q, h|
      h[q.name.to_sym] = available[q.name.to_sym].merge(:unit => q.unit, :value => q.value, :format => q.format)
      h
    end.reverse_merge(available)
  end

  def self.set(tenant, quotas)
    quotas.each do |name, values|
      q = tenant.tenant_quotas.where(:name => name).last || new(values.merge(:tenant => tenant, :name => name))
      q.unit ||= q.default_unit
      q.update_attributes!(values)
    end
    # Delete any quotas that were not passed in
    destroy_all(:tenant => tenant, :name => (available.keys.sort - quotas.symbolize_keys.keys.sort))
    tenant.clear_association_cache
  end

  def format
    QUOTAS.fetch_path(name.to_sym, :format).to_s
  end

  def default_unit
    QUOTAS.fetch_path(name.to_sym, :unit).to_s
  end
end

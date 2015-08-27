class TenantQuota < ActiveRecord::Base
  belongs_to :tenant

  QUOTAS = {
    :cpu_allocated => {
      :unit   => :mhz,
      :format => :mhz
    },
    :mem_allocated => {
      :unit   => :bytes,
      :format => :gigabytes_human
    },
    :storage_allocated => {
      :unit   => :bytes,
      :format => :gigabytes_human
    },
    :vms_allocated => {
      :unit   => :fixnum,
      :format => :general_number_precision_0
    },
    :templates_allocated => {
      :unit   => :fixnum,
      :format => :general_number_precision_0
    }
  }

  NAMES = QUOTAS.stringify_keys

  validates_inclusion_of :name, :in => NAMES
  validates_presence_of  :unit, :value

  def self.available
    QUOTAS
  end

  def self.get(tenant)
    where(:tenant => tenant).inject({}) do |h, q|
      h[q.name.to_sym] = {:unit => q.unit, :value => q.value, :format => q.format}
      h
    end
  end

  def self.set(tenant, quotas)
    quotas.each do |name, values|
      q = where(:tenant => tenant, :name => name).last || new(values.merge(:tenant => tenant, :name => name))
      q.unit ||= q.default_unit
      q.update_attributes!(values)
    end
    # Deletes
    destroy_all(:tenant => tenant, :name => (available.keys.sort - quotas.symbolize_keys.keys.sort))
  end

  def format
    QUOTAS.fetch_path(name.to_sym, :format).to_s
  end

  def default_unit
    QUOTAS.fetch_path(name.to_sym, :unit).to_s
  end
end

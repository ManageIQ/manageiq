class TenantQuota < ApplicationRecord
  belongs_to :tenant

  QUOTA_BASE = {
    :cpu_allocated       => {
      :unit          => :fixnum,
      :format        => :general_number_precision_0,
      :text_modifier => "Count".freeze
    },
    :mem_allocated       => {
      :unit          => :bytes,
      :format        => :gigabytes_human,
      :text_modifier => "GB".freeze
    },
    :storage_allocated   => {
      :unit          => :bytes,
      :format        => :gigabytes_human,
      :text_modifier => "GB".freeze
    },
    :vms_allocated       => {
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

  DEFAULT_TEXT_FOR_ZERO_VALUES = {
    :total     => "Not defined".freeze,
    :available => "Not applicable".freeze
  }

  NAMES = QUOTA_BASE.keys.map(&:to_s)

  validates :name, :inclusion => {:in => NAMES}
  validates :unit, :value, :presence => true
  validates :value, :numericality => {:greater_than => 0}
  validates :warn_value, :numericality => {:greater_than => 0}, :if => "warn_value.present?"

  validate :check_for_over_allocation

  scope :cpu_allocated,       -> { where(:name => :cpu_allocated) }
  scope :mem_allocated,       -> { where(:name => :mem_allocated) }
  scope :storage_allocated,   -> { where(:name => :storage_allocated) }
  scope :vms_allocated,       -> { where(:name => :vms_allocated) }
  scope :templates_allocated, -> { where(:name => :templates_allocated) }

  virtual_column :name, :type => :string
  virtual_column :total, :type => :integer
  virtual_column :used, :type => :float
  virtual_column :allocated, :type => :float
  virtual_column :available, :type => :float

  alias_attribute :total, :value

  before_validation(:on => :create) do
    self.unit = default_unit unless unit.present?
  end

  def self.format_quota_value(field, field_value, tenant_quota_name)
    if field == "tenant_quotas.name"
      TenantQuota.tenant_quota_description(tenant_quota_name.to_sym)
    else
      row = QUOTA_BASE[tenant_quota_name.to_sym]
      OpsHelper::TextualSummary.convert_to_format(row[:format], row[:text_modifier], field_value)
    end
  end

  def self.can_format_field?(field, tenant_quota_name)
    table_field, = field.split(".")
    to_s.tableize == table_field ? NAMES.include?(tenant_quota_name) : false
  end

  def self.default_text_for(metric)
    DEFAULT_TEXT_FOR_ZERO_VALUES[metric]
  end

  def self.quota_definitions
    @quota_definitions ||= QUOTA_BASE.each_with_object({}) do |(name, value), h|
      h[name] = value.merge(:description => tenant_quota_description(name), :value => nil, :warn_value => nil)
    end
  end

  def self.tenant_quota_description(name)
    case name
    when :cpu_allocated
      _("Allocated Virtual CPUs")
    when :mem_allocated
      _("Allocated Memory in GB")
    when :storage_allocated
      _("Allocated Storage in GB")
    when :vms_allocated
      _("Allocated Number of Virtual Machines")
    when :templates_allocated
      _("Allocated Number of Templates")
    end
  end

  def allocated
    tenant.children.includes(:tenant_quotas).map do |c|
      cq = c.tenant_quotas.send(name).take
      cq.value if cq
    end.compact.sum
  end

  def available
    value - tenant.children.includes(:tenant_quotas).map do |c|
      cq = c.tenant_quotas.send(name).take
      cq.value if cq
    end.compact.sum - used
  end

  def used
    method = "#{name.split("_").first}_used"
    @used ||= send(method)
  end

  def cpu_used
    tenant.allocated_vcpu
  end

  def mem_used
    tenant.allocated_memory
  end

  def storage_used
    tenant.allocated_storage
  end

  def vms_used
    tenant.active_vms.count
  end

  def templates_used
    tenant.miq_templates.count
  end

  # remove all quotas that are not listed in the keys to keep
  # e.g.: tenant.tenant_quotas.destroy_missing_quotas(include_keys)
  # NOTE: these are already local, no need to hit db to find them
  def self.destroy_missing(keep)
    keep = keep.map(&:to_s)
    deletes = all.select { |tq| !keep.include?(tq.name) }
    delete(deletes)
  end

  def quota_hash
    self.class.quota_definitions[name.to_sym].merge(:unit => unit, :value => value, :warn_value => warn_value, :format => format) # attributes
  end

  def format
    self.class.quota_definitions.fetch_path(name.to_sym, :format).to_s
  end

  def default_unit
    self.class.quota_definitions.fetch_path(name.to_sym, :unit).to_s
  end

  def check_for_over_allocation
    return unless value_changed?

    # Root tenant has no (unlimited) quota
    # First level tenant can also have unlimited quota
    return if tenant.root? || tenant.parent.root?

    oval, nval = changes["value"]

    # Check that the new value is >= the amount that was already allocated to child tenants
    if nval < allocated
      errors.add(name, "quota is over allocated, #{nval} was requested but only #{nval - allocated} is available")
      return
    end

    # Check that new quota is a least as much as was already used
    if nval < used
      errors.add(name, "quota is under allocated, #{nval} was requested but #{used} has already been used")
      return
    end

    diff = (nval || 0) - (oval || 0)

    # Check if the parent has enough quota available to give to the child
    parent_quota = tenant.parent.tenant_quotas.send(name).take
    unless parent_quota.nil?
      if parent_quota.available < diff
        errors.add(name, "quota is over allocated, parent tenant does not have enough quota")
      end
    end
  end
end

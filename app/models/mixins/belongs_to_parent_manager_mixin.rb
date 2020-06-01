module BelongsToParentManagerMixin
  extend ActiveSupport::Concern

  PROVIDER_NAME = "Network Manager".freeze

  included do
    belongs_to :parent_manager,
               :foreign_key => :parent_ems_id,
               :class_name  => "ManageIQ::Providers::BaseManager",
               :autosave    => true

    has_many :availability_zones,            -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :flavors,                       -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_tenants,                 -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_database_flavors,        -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_tenants,                 -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_resource_quotas,         -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_volumes,                 -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_volume_types,            -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_volume_backups,          -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_volume_snapshots,        -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_object_store_containers, -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_object_store_objects,    -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_services,                -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :cloud_databases,               -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :hosts,                         -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :vms,                           -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :miq_templates,                 -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id
    has_many :vms_and_templates,             -> { where.not(:ems_id => nil) }, :primary_key => :parent_ems_id, :foreign_key => :ems_id

    virtual_total :total_vms, :vms
    virtual_total :total_miq_templates, :miq_templates
    virtual_total :total_vms_and_templates, :vms_and_templates

    # Relationships delegated to parent manager
    virtual_delegate :orchestration_stacks,
                     :orchestration_stacks_resources,
                     :direct_orchestration_stacks,
                     :resource_groups,
                     :key_pairs,
                     :to        => :parent_manager,
                     :allow_nil => true,
                     :default   => []

    def name
      "#{parent_manager.try(:name)} #{PROVIDER_NAME}"
    end

    def self.find_object_for_belongs_to_filter(name)
      name.gsub!(" #{self::PROVIDER_NAME}", "")
      includes(:parent_manager).find_by(:parent_managers_ext_management_systems => {:name => name})
    end
  end
end

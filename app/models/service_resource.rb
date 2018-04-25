class ServiceResource < ApplicationRecord
  STATUS_ACTIVE    = 'Active'.freeze
  STATUS_APPROVED  = 'Approved'.freeze
  STATUS_COMPLETED = 'Completed'.freeze
  STATUS_FAILED    = 'Failed'.freeze
  STATUS_QUEUED    = 'Queued'.freeze

  belongs_to :service_template
  belongs_to :service
  belongs_to :resource, :polymorphic => true
  belongs_to :source,   :polymorphic => true

  default_value_for :group_idx, 0
  default_value_for :scaling_min, 1
  default_value_for :scaling_max, -1
  default_value_for :provision_index, 0

  virtual_column :resource_name,        :type => :string
  virtual_column :resource_description, :type => :string

  def readonly?
    return true if super

    service_template.try(:readonly?)
  end

  def resource_name
    virtual_column_resource_value(:name).to_s
  end

  def resource_description
    virtual_column_resource_value(:description).to_s
  end

  private

  def virtual_column_resource_value(key)
    return "" if resource.nil?
    return "" unless resource.respond_to?(key)
    resource.send(key)
  end
end

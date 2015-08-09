class CreateContainerResourceQuota < ActiveRecord::Migration
  def change
    create_table :container_quotas do |t|
      t.string     :name
      t.datetime   :creation_timestamp
      t.string     :resource_version
      t.string     :ems_ref
      t.belongs_to :container_project, :type => :bigint
      t.belongs_to :ems, :type => :bigint
    end

    create_table :container_quota_items do |t|
      t.string     :resource
      t.string     :quota_desired
      t.string     :quota_enforced
      t.string     :quota_observed
      t.belongs_to :container_quota, :type => :bigint
    end
  end
end

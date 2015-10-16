class CreateContainerLimitRange < ActiveRecord::Migration
  def change
    create_table :container_limits do |t|
      t.string     :name
      t.datetime   :creation_timestamp
      t.string     :resource_version
      t.string     :ems_ref
      t.belongs_to :container_project, :type => :bigint
      t.belongs_to :ems, :type => :bigint
    end

    create_table :container_limit_items do |t|
      t.string     :item_type
      t.string     :resource
      t.string     :max
      t.string     :min
      t.string     :default
      t.string     :default_request
      t.string     :max_limit_request_ratio
      t.belongs_to :container_limit, :type => :bigint
    end
  end
end

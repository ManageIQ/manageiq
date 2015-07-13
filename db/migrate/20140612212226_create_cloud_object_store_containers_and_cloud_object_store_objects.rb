class CreateCloudObjectStoreContainersAndCloudObjectStoreObjects < ActiveRecord::Migration
  def change
    create_table :cloud_object_store_containers do |t|
      t.string     :ems_ref
      t.string     :key
      t.integer    :object_count
      t.bigint     :bytes
      t.belongs_to :ems,                          :type => :bigint
      t.belongs_to :cloud_tenant,                 :type => :bigint
    end

    create_table :cloud_object_store_objects do |t|
      t.string     :ems_ref
      t.string     :etag
      t.string     :key
      t.string     :content_type
      t.bigint     :content_length
      t.datetime   :last_modified
      t.belongs_to :ems,                          :type => :bigint
      t.belongs_to :cloud_tenant,                 :type => :bigint
      t.belongs_to :cloud_object_store_container, :type => :bigint
    end
  end
end

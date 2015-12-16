class CreateContainerBuilds < ActiveRecord::Migration
  def change
    create_table :container_builds do |t|
      t.string     :ems_ref
      t.string     :name
      t.timestamp  :creation_timestamp
      t.string     :resource_version
      t.string     :namespace
      t.string     :service_account

      t.string     :build_source_type
      t.string     :source_binary
      t.string     :source_dockerfile
      t.string     :source_git
      t.string     :source_context_dir
      t.string     :source_secret

      t.string     :output_name

      t.bigint     :completion_deadline_seconds

      t.belongs_to :container_project, :type => :bigint
      t.belongs_to :ems, :type => :bigint
    end
    add_index :container_builds, :ems_id

    create_table :container_build_pods do |t|
      t.string     :ems_ref
      t.string     :name
      t.timestamp  :creation_timestamp
      t.string     :resource_version
      t.string     :namespace

      t.string     :message
      t.string     :phase
      t.string     :reason
      t.string     :output_docker_image_reference
      t.string     :completion_timestamp
      t.string     :start_timestamp
      t.bigint     :duration

      t.belongs_to :container_build, :type => :bigint
      t.belongs_to :ems, :type => :bigint
    end
    add_index :container_build_pods, :ems_id

    add_column :container_groups, :container_build_pod_id, :bigint
  end
end

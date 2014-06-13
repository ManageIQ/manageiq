class CreateMiqHostProvisionRequests < ActiveRecord::Migration
  def self.up
    create_table :miq_host_provision_requests do |t|
      t.string      :description
      t.string      :state
      t.string      :provision_type
      t.string      :userid
      t.text        :options
      t.string      :message
      t.string      :status
      t.timestamps
    end

    create_table :miq_host_provisions do |t|
      t.string      :description
      t.string      :state
      t.string      :provision_type
      t.string      :userid
      t.text        :options
      t.string      :message
      t.string      :status
      t.bigint      :miq_host_provision_request_id
      t.bigint      :host_id
      t.timestamps
    end
  end

  def self.down
    drop_table :miq_host_provision_requests
    drop_table :miq_host_provisions
  end
end

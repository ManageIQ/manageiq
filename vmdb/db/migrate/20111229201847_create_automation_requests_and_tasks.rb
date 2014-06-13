class CreateAutomationRequestsAndTasks < ActiveRecord::Migration
  def self.up
    create_table :automation_requests do |t|
      t.column  :description,       :string
      t.column  :state,             :string
      t.column  :status,            :string
      t.column  :userid,            :string
      t.column  :options,           :text
      t.column  :created_on,        :timestamp
      t.column  :updated_on,        :timestamp
      t.column  :message,           :string
    end

    create_table :automation_tasks do |t|
      t.column  :description,       :string
      t.column  :state,             :string
      t.column  :status,            :string
      t.column  :userid,            :string
      t.column  :options,           :text
      t.column  :created_on,        :timestamp
      t.column  :updated_on,        :timestamp
      t.column  :message,           :string
      t.column  :automation_request_id,  :bigint
    end
  end

  def self.down
    drop_table :automation_requests
    drop_table :automation_tasks
  end
end

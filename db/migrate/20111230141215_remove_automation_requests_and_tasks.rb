class RemoveAutomationRequestsAndTasks < ActiveRecord::Migration
  class MiqRequest < ActiveRecord::Base
    serialize :options
  end

  class AutomationRequest < MiqRequest
  end

  class AutomationRequestV4 < ActiveRecord::Base
    self.table_name = 'automation_requests'
    serialize :options
  end

  class MiqRequestTask < ActiveRecord::Base
    serialize :options
  end

  class AutomationTaskV4 < ActiveRecord::Base
    self.table_name = 'automation_tasks'
    serialize :options
  end

  class AutomationTask < MiqRequestTask
    # mawagner: Table name here is miq_request_tasks, NOT automation_tasks!
  end

  class User < ActiveRecord::Base
  end

  def self.convert_automation_requests
    # Retrieve all AutomationRequestV4 records (table name: automation_requests)
    AutomationRequestV4.all.each do |ar|
      miq_request_id = ar.options.delete(:miq_request_id).to_i
      # Pair them up with an AutomationRequest, which will become the new record:
      mr = AutomationRequest.where(:id => miq_request_id).first

      next if mr.nil?

      attrs = ar.attributes.dup
      %w{id description created_on }.each {|key| attrs.delete(key)}
      attrs["request_type"]   = 'automation'
      attrs["request_state"]  = attrs.delete("state")
      attrs["requester_name"] = attrs["userid"]
      user = User.where(:userid => attrs["userid"]).first
      attrs["requester_id"]   = user.id unless user.nil?
      mr.update_attributes!(attrs)

      # And, for our associated AutomationTaskV4 records, move them to
      # AutomationTask records (table name: miq_request_tasks)
      AutomationTaskV4.where(:automation_request_id => ar.id).each do |task|
        attrs = task.attributes.dup
        %w{id created_on automation_request_id}.each {|key| attrs.delete(key)}
        attrs["request_type"]   = 'automation'
        attrs["miq_request_id"] = mr.id
        AutomationTask.create!(attrs)
      end
    end
  end

  def self.up
    say_with_time("Converting AutomationRequests to MiqRequests") { self.convert_automation_requests }
    drop_table :automation_requests # Used by AutomationRequestV4, NOT AutomationRequest model
    drop_table :automation_tasks    # Used by AutomationTaskV4, NOT AutomationTask model
  end

  def self.down
    create_table :automation_requests do |t|
      t.column  :description,           :string
      t.column  :state,                 :string
      t.column  :status,                :string
      t.column  :userid,                :string
      t.column  :options,               :text
      t.column  :created_on,            :timestamp
      t.column  :updated_on,            :timestamp
      t.column  :message,               :string
    end

    create_table :automation_tasks do |t|
      t.column  :description,           :string
      t.column  :state,                 :string
      t.column  :status,                :string
      t.column  :userid,                :string
      t.column  :options,               :text
      t.column  :created_on,            :timestamp
      t.column  :updated_on,            :timestamp
      t.column  :message,               :string
      t.column  :automation_request_id, :bigint
    end
  end
end

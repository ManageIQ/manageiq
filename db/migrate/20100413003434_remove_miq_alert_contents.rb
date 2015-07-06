class RemoveMiqAlertContents < ActiveRecord::Migration
  class MiqAlert < ActiveRecord::Base
    serialize :options
    has_many :miq_alert_contents, :class_name => "::RemoveMiqAlertContents::MiqAlertContent"
  end

  class MiqAction < ActiveRecord::Base
    serialize :options
  end

  class MiqAlertContent < ActiveRecord::Base
    belongs_to :miq_action, :class_name => "::RemoveMiqAlertContents::MiqAction"
  end

  def self.up
    say_with_time("Migrate MiqAlertContent into MiqAlert") do
      MiqAlert.includes(:miq_alert_contents => :miq_action).each do |alert|
        tos = []
        from = nil
        alert.options = {:notifications => {}}
        alert.miq_alert_contents.each do |c|
          action = c.miq_action
          next if action.options.blank?

          case action.action_type
          when "email"
            from =  action.options[:from] unless action.options[:from].blank?
            tos  << action.options[:to]
          when "snmp_trap"
            alert.options[:notifications][:snmp] ||= action.options
          end
        end

        alert.options[:notifications][:email] = {:from => from, :to => tos} unless tos.blank?
        alert.save                                                          unless alert.options[:notifications].blank?
      end
    end

    drop_table  :miq_alert_contents
  end

  def self.down
    create_table "miq_alert_contents", :force => true do |t|
      t.integer  "miq_alert_id"
      t.integer  "miq_action_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "sequence"
      t.boolean  "synchronous"
      t.text     "reserved"
    end
  end
end

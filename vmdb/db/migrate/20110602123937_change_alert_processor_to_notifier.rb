class ChangeAlertProcessorToNotifier < ActiveRecord::Migration

  class MiqQueue < ActiveRecord::Base
    self.table_name = "miq_queue"
  end

  class ServerRole < ActiveRecord::Base; end

  def self.up
    say_with_time("Update MiqQueue messages with 'alert_processor' role to 'notifier' role") do
      MiqQueue.where(:role => "alert_processor").update_all({:role => "notifier"})
    end

    say_with_time("Update ServerRole 'alert_processor' role to 'notifier' role") do
      ServerRole.where(:name => "alert_processor").update_all({:name => "notifier", :description => "Notifier"})
    end
  end

  def self.down
    say_with_time("Update MiqQueue messages with 'notifier' role to 'alert_processor' role") do
      MiqQueue.where(:role => "notifier").update_all({:role => "alert_processor"})
    end

    say_with_time("Update ServerRole 'notifier' role to 'alert_processor' role") do
      ServerRole.where(:name => "notifier").update_all({:name => "alert_processor", :description => "Alert Processor"})
    end
  end
end

require "spec_helper"
require Rails.root.join("db/migrate/20110602123937_change_alert_processor_to_notifier.rb")

describe ChangeAlertProcessorToNotifier do
  migration_context :up do
    let(:queue_stub)       { migration_stub(:MiqQueue) }
    let(:server_role_stub) { migration_stub(:ServerRole) }

    it "changes miq_queue rows with 'alert_processor' role to 'notifier'" do
      message = queue_stub.create!(:role => "alert_processor")

      migrate

      message.reload.role.should == 'notifier'
    end

    it "changes server_roles rows with 'alert_processor' role to 'notifier'" do
      server_role = server_role_stub.create!(:name => "alert_processor")

      migrate

      server_role.reload
      server_role.name.should == 'notifier'
      server_role.description.should == "Notifier"
    end
  end

  migration_context :down do
    let(:queue_stub)       { migration_stub(:MiqQueue) }
    let(:server_role_stub) { migration_stub(:ServerRole) }

    it "changes miq_queue rows with 'notifier' role to 'alert_processor'" do
      message = queue_stub.create!(:role => "notifier")

      migrate

      message.reload.role.should == 'alert_processor'
    end

    it "changes server_roles rows with 'notifier' role to 'alert_processor'" do
      server_role = server_role_stub.create!(:name => "notifier")

      migrate

      server_role.reload
      server_role.name.should == 'alert_processor'
      server_role.description.should == "Alert Processor"
    end
  end
end

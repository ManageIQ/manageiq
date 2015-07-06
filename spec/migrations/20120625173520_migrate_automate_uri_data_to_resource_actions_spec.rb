require "spec_helper"
require Rails.root.join("db/migrate/20120625173520_migrate_automate_uri_data_to_resource_actions.rb")

describe MigrateAutomateUriDataToResourceActions do
  migration_context :up do
    context "migrates AutomationUri data to ResourceAction" do
      let(:automation_uri_stub)  { migration_stub(:AutomationUri)  }
      let(:resource_action_stub) { migration_stub(:ResourceAction) }

      it "normal case" do
        auto_uri = automation_uri_stub.create!(
          :uri_path    => "/ns/klass/instance",
          :uri_message => "message",
          :options     => {:attributes => {"testing" => true}}
        )

        migrate

        auto_uri.reload
        action = resource_action_stub.where(:resource_type => "AutomationUri", :resource_id => auto_uri.id).first

        action.should have_attributes(
          :action        => "automation_button",
          :ae_namespace  => "ns",
          :ae_class      => "klass",
          :ae_instance   => "instance",
          :ae_message    => "message",
          :ae_attributes =>  {"testing" => true}
        )
      end

      it "rejects MiqAeEngine default attributes" do
        auto_uri = automation_uri_stub.create!(
          :uri_path => "/",
          :options  => {:attributes => {"User::user" => true}}
        )

        migrate

        auto_uri.reload
        action = resource_action_stub.where(:resource_type => "AutomationUri", :resource_id => auto_uri.id).first

        action[:ae_attributes].should == {}
      end
    end
  end

  migration_context :down do
    context "Reverts AutomationUri data to ResourceAction" do
      let(:automation_uri_stub)  { migration_stub(:AutomationUri)  }
      let(:resource_action_stub) { migration_stub(:ResourceAction) }

      it "normal case" do

        auto_uri = automation_uri_stub.create!()
        action = resource_action_stub.create!(
          :resource_type => "AutomationUri",
          :resource_id   => auto_uri.id,
          :action        => "automation_button",
          :ae_namespace  => "ns",
          :ae_class      => "klass",
          :ae_instance   => "instance",
          :ae_message    => "message",
          :ae_attributes =>  {"testing" => true, "request" => true}
        )

        migrate

        auto_uri.reload
        auto_uri.should have_attributes(
          :uri         => "/ns/klass/instance?testing=true#message",
          :uri_path    => "/ns/klass/instance",
          :uri_message => "message",
          :options     => {:attributes => {"testing" => true, "request" => true}}
        )

        lambda { action.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end

      it "AutomationUri without a ResourceAction" do
        auto_uri = automation_uri_stub.create!
        attrs = auto_uri.attributes.dup

        migrate

        auto_uri.reload.should have_attributes(attrs)
      end
    end
  end
end

require "spec_helper"
require Rails.root.join("db/migrate/20100413003434_remove_miq_alert_contents.rb")

describe RemoveMiqAlertContents do
  before do
    pending("spec can only run on region 0")  unless ActiveRecord::Base.my_region_number == 0
  end

  migration_context :up do
    let(:alert_stub)         { migration_stub(:MiqAlert) }
    let(:action_stub)        { migration_stub(:MiqAction) }
    let(:alert_content_stub) { migration_stub(:MiqAlertContent) }

    context "migrates MiqAlertContent into MiqAlert for" do
      let(:alert) { alert_stub.create! }

      it "email" do
        action1 = action_stub.create!(:action_type => "email", :guid => MiqUUID.new_guid, :options => {:from => "abc", :to => "def"})
        action2 = action_stub.create!(:action_type => "email", :guid => MiqUUID.new_guid, :options => {:from => "abc", :to => "ghi"})
        alert_content_stub.create!(:miq_alert_id => alert.id, :miq_action_id => action1.id)
        alert_content_stub.create!(:miq_alert_id => alert.id, :miq_action_id => action2.id)

        migrate

        alert.reload
        alert.options[:notifications][:email][:from].should == "abc"
        alert.options[:notifications][:email][:to].should match_array ["def", "ghi"]
      end

      it "email missing :from" do
        action = action_stub.create!(:action_type => "email", :options => {:to => "def"})
        alert_content_stub.create!(:miq_alert_id => alert.id, :miq_action_id => action.id)

        migrate

        alert.reload.options.should == {:notifications => {:email => {:from => nil, :to => ["def"]}}}
      end

      it "snmp" do
        action = action_stub.create!(:action_type => "snmp_trap", :options => {:snmp_options => :abc})
        alert_content_stub.create!(:miq_alert_id => alert.id, :miq_action_id => action.id)

        migrate

        alert.reload.options.should == {:notifications => {:snmp => {:snmp_options => :abc}}}
      end

      it "email and snmp" do
        action1 = action_stub.create!(:action_type => "snmp_trap", :guid => MiqUUID.new_guid, :options => {:snmp_options => :abc})
        action2 = action_stub.create!(:action_type => "email",     :guid => MiqUUID.new_guid, :options => {:from => "abc", :to => "def"})
        alert_content_stub.create!(:miq_alert_id => alert.id, :miq_action_id => action1.id)
        alert_content_stub.create!(:miq_alert_id => alert.id, :miq_action_id => action2.id)

        migrate

        alert.reload.options.should == {
          :notifications =>
            {
              :snmp  => {:snmp_options => :abc},
              :email => {:from => "abc", :to => ["def"]}
            }
        }
      end

      it "unhandled action_type" do
        action = action_stub.create!(:action_type => "other", :options => {:snmp_options => {}})
        alert_content_stub.create!(:miq_alert_id => alert.id, :miq_action_id => action.id)

        alert_stub.any_instance.should_receive(:save).never
        migrate
      end
    end
  end
end

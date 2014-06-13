require "spec_helper"

describe ResourceAction do
  context "#deliver_to_automate_from_dialog" do
    before(:each) do
      MiqServer.stub(:my_zone).and_return("default")
      @ra = FactoryGirl.create(:resource_action)
      @q_args = {
        :namespace        => nil,
        :class_name       => nil,
        :instance_name    => nil,
        :automate_message => nil,
        :user_id          => nil,
        :attrs            => {},
      }

      @q_options = {
        :class_name  => 'MiqAeEngine',
        :method_name => 'deliver',
        :args        => [@q_args],
        :role        => 'automate',
        :zone        => nil,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :task_id     => "#{@ra.class.name.underscore}_#{@ra.id}",
        :msg_timeout => 3600
      }
    end

    it "with no target" do
      target             = nil
      dialog_hash_values = {}
      MiqQueue.should_receive(:put).with(@q_options).once
      @ra.deliver_to_automate_from_dialog(dialog_hash_values, target)
    end

    it "with target" do
      target             = FactoryGirl.create(:vm_vmware)
      dialog_hash_values = {}
      @q_args[:object_type] = target.class.name
      @q_args[:object_id]   = target.id
      MiqQueue.should_receive(:put).with(@q_options).once
      @ra.deliver_to_automate_from_dialog(dialog_hash_values, target)
    end
  end

  it "#ae_path" do
    ra = FactoryGirl.build(:resource_action,
                           :ae_namespace => "NAMESPACE",
                           :ae_class     => "CLASS",
                           :ae_instance  => "INSTANCE")
    ra.ae_path.should == "/NAMESPACE/CLASS/INSTANCE"
  end

  it "#ae_uri" do
    ra = FactoryGirl.build(:resource_action,
                           :ae_namespace => "NAMESPACE",
                           :ae_class     => "CLASS",
                           :ae_instance  => "INSTANCE")
    ra.ae_uri.should == ra.ae_path

    ra.ae_message = "CREATE"
    ra.ae_uri.should == "#{ra.ae_path}#CREATE"

    ra.ae_attributes = { "FOO1" => "BAR1", "FOO2" => "BAR2" }
    ra.ae_uri.should == "#{ra.ae_path}?FOO1=BAR1&FOO2=BAR2#CREATE"
  end

end

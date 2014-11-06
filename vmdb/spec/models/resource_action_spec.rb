require "spec_helper"

describe ResourceAction do
  context "#deliver_to_automate_from_dialog" do
    let(:zone_name) { "default" }
    let(:ra) { FactoryGirl.create(:resource_action) }
    let(:q_args) do
      {
        :namespace        => nil,
        :class_name       => nil,
        :instance_name    => nil,
        :automate_message => nil,
        :user_id          => nil,
        :attrs            => {},
      }
    end
    let(:q_options) do
      {
        :class_name  => 'MiqAeEngine',
        :method_name => 'deliver',
        :args        => [q_args],
        :role        => 'automate',
        :zone        => zone_name,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :task_id     => "#{ra.class.name.underscore}_#{ra.id}",
        :msg_timeout => 3600
      }
    end

    before do
      MiqServer.stub(:my_zone).and_return(zone_name)
    end

    context 'with no target' do
      let(:zone_name) { nil }

      it "validates queue entry" do
        target             = nil
        MiqQueue.should_receive(:put).with(q_options).once
        ra.deliver_to_automate_from_dialog({}, target)
      end
    end

    context 'with target' do
      it "validates queue entry" do
        target               = FactoryGirl.create(:vm_vmware)
        q_args[:object_type] = target.class.name
        q_args[:object_id]   = target.id
        MiqQueue.should_receive(:put).with(q_options).once
        ra.deliver_to_automate_from_dialog({}, target)
      end
    end
  end

  context "uri validation" do
    let(:ra) do
      FactoryGirl.build(:resource_action,
                        :ae_namespace => "NAMESPACE",
                        :ae_class     => "CLASS",
                        :ae_instance  => "INSTANCE")
    end

    it "#ae_path" do
      ra.ae_path.should eq("/NAMESPACE/CLASS/INSTANCE")
    end

    it "#ae_uri" do
      ra.ae_uri.should eq(ra.ae_path)
    end

    it "uri with message" do
      ra.ae_message = "CREATE"
      ra.ae_uri.should eq("#{ra.ae_path}#CREATE")
    end

    it "uri with message and attributes" do
      ra.ae_message = "CREATE"
      ra.ae_attributes = {"FOO1" => "BAR1", "FOO2" => "BAR2"}
      ra.ae_uri.should eq("#{ra.ae_path}?FOO1=BAR1&FOO2=BAR2#CREATE")
    end
  end
end

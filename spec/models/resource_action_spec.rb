RSpec.describe ResourceAction do
  context "#deliver_to_automate_from_dialog" do
    let(:user) { FactoryBot.create(:user_with_group) }
    let(:zone_name) { "default" }
    let(:ra) { FactoryBot.create(:resource_action) }
    let(:miq_server) { FactoryBot.create(:miq_server) }
    let(:ae_attributes) { {} }
    let(:q_args) do
      {
        :namespace        => nil,
        :class_name       => nil,
        :instance_name    => nil,
        :automate_message => nil,
        :user_id          => user.id,
        :miq_group_id     => user.current_group.id,
        :tenant_id        => user.current_tenant.id,
        :username         => user.userid,
        :attrs            => ae_attributes,
        :open_url_task_id => nil
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
      allow(MiqServer).to receive(:my_zone).and_return(zone_name)
      allow(MiqServer).to receive(:my_server).and_return(miq_server)
    end

    context 'with no target' do
      let(:zone_name) { nil }

      it "validates queue entry" do
        target             = nil
        expect(MiqQueue).to receive(:put).with(q_options).once
        ra.deliver_to_automate_from_dialog({}, target, user)
      end
    end

    context 'with target' do
      it "validates queue entry" do
        target               = FactoryBot.create(:vm_vmware)
        q_args[:object_type] = target.class.base_class.name
        q_args[:object_id]   = target.id
        expect(MiqQueue).to receive(:put).with(q_options).once
        ra.deliver_to_automate_from_dialog({}, target, user)
      end
    end

    context 'with targets' do
      let(:zone_name) { nil }
      it "validates queue entry" do
        targets = [FactoryBot.create(:vm_vmware), FactoryBot.create(:vm_vmware)]
        ae_attributes[:target_object_type] = targets.first.class.base_class.name
        klass = targets.first.id.class
        ae_attributes['Array::target_object_ids'] = targets.collect { |t| "#{klass}::#{t.id}" }.join(",")
        expect(MiqQueue).to receive(:put).with(q_options).once
        ra.deliver_to_automate_from_dialog({}, targets, user)
      end
    end

    context '#deliver_to_automate_from_dialog_with_miq_task' do
      it '' do
        allow(ra).to(receive(:deliver_to_automate_from_dialog))
        miq_task = MiqTask.find(ra.deliver_to_automate_from_dialog_with_miq_task({}, nil, user))
        expect(miq_task.state).to(eq(MiqTask::STATE_QUEUED))
        expect(miq_task.status).to(eq(MiqTask::STATUS_OK))
        expect(miq_task.message).to(eq('MiqTask has been queued.'))
      end
    end
  end

  context "uri validation" do
    let(:ra) do
      FactoryBot.build(:resource_action,
                        :ae_namespace => "NAMESPACE",
                        :ae_class     => "CLASS",
                        :ae_instance  => "INSTANCE")
    end

    it "#ae_path" do
      expect(ra.ae_path).to eq("/NAMESPACE/CLASS/INSTANCE")
    end

    it "#ae_uri" do
      expect(ra.ae_uri).to eq(ra.ae_path)
    end

    it "uri with message" do
      ra.ae_message = "CREATE"
      expect(ra.ae_uri).to eq("#{ra.ae_path}#CREATE")
    end

    it "uri with message and attributes" do
      ra.ae_message = "CREATE"
      ra.ae_attributes = {"FOO1" => "BAR1", "FOO2" => "BAR2"}
      expect(ra.ae_uri).to eq("#{ra.ae_path}?FOO1=BAR1&FOO2=BAR2#CREATE")
    end
  end

  context "#automate_queue_hash" do
    let(:button) { FactoryBot.create(:custom_button, :applies_to_class => "Vm") }
    let(:ra)     { FactoryBot.create(:resource_action, :resource => button) }
    let(:user)   { FactoryBot.create(:user_with_group) }
    let(:target) { FactoryBot.create(:vm_vmware) }

    it "passes result_format" do
      expect(ra.automate_queue_hash(target, {"result_format"=>"ignore"}, user)).to include(:attrs => {"result_format"=>"ignore"})
    end

    it "does not pass result_format by default" do
      expect(ra.automate_queue_hash(target, {}, user)).not_to include(:attrs => {"result_format"=>"ignore"})
    end
  end
end

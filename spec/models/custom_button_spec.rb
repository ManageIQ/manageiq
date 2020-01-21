describe CustomButton do
  describe '.with_array_order' do
    context 'order by array' do
      let!(:custom_button_1) { FactoryBot.create(:custom_button, :name => 'AAA', :applies_to_id => 100, :applies_to_class => Vm) }
      let!(:custom_button_2) { FactoryBot.create(:custom_button, :name => 'BBB', :applies_to_id => 200, :applies_to_class => Vm) }
      let!(:custom_button_3) { FactoryBot.create(:custom_button, :name => 'CCC', :applies_to_id => 300, :applies_to_class => Vm) }

      context 'by bigint column' do
        it 'orders by memory_shares column' do
          expect(CustomButton.with_array_order(%w(300 100 200), :applies_to_id).ids).to eq([custom_button_3.id, custom_button_1.id, custom_button_2.id])
        end
      end

      context 'by string column' do
        it 'orders by name column' do
          expect(CustomButton.with_array_order(%w(BBB AAA CCC), :name, :text).ids).to eq([custom_button_2.id, custom_button_1.id, custom_button_3.id])
        end
      end
    end
  end

  context "with no buttons" do
    describe '#evaluate_enablement_expression_for' do
      let(:miq_expression) { MiqExpression.new('EQUAL' => {'field' => 'Vm-name', 'value' => 'vm_1'}) }
      let(:vm)             { FactoryBot.create(:vm_vmware, :name => 'vm_1') }
      let(:custom_button) do
        FactoryBot.create(:custom_button, :applies_to => vm.class, :name => "foo", :description => "foo foo")
      end

      it 'evaluates enablement expression when expression is not set' do
        expect(custom_button.evaluate_enablement_expression_for(vm)).to be_truthy
      end

      it 'evaluates enablement expression when expression is set and method is called for list' do
        custom_button.enablement_expression = miq_expression
        expect(custom_button.evaluate_enablement_expression_for(nil)).to be_falsey
      end

      it 'evaluates enablement expression when expression is set and evaluated to true' do
        custom_button.enablement_expression = miq_expression
        expect(custom_button.evaluate_enablement_expression_for(vm)).to be_truthy
      end

      it 'evaluates enablement expression when expression is set and evaluated to false' do
        custom_button.enablement_expression = miq_expression
        vm.name = 'XXX'
        expect(custom_button.evaluate_enablement_expression_for(vm)).to be_falsey
      end
    end

    it "should validate there are no buttons" do
      expect(described_class.count).to eq(0)
    end

    context "when I create a button via save_as_button class method" do
      before do
        @button_name   = "Power ON"
        @button_text   = "Power ON during Business Hours ONLY"
        @button_number = 3
        @button_class  = "Vm"
        @target_id     = 2
        @ae_name       = 'Automation'
        @ae_attributes = {'phrase' => 'Hello World'}
        @ae_uri        = MiqAeEngine.create_automation_object(@ae_name, @ae_attributes)
        @userid        = "guest"
        uri_path, uri_attributes, uri_message = CustomButton.parse_uri(@ae_uri)
        @button = FactoryBot.create(:custom_button,
          :name             => @button_name,
          :description      => @button_text,
          :applies_to_class => @button_class,
          :applies_to_id    => @target_id,
          :uri              => @ae_uri,
          :uri_path         => uri_path,
          :uri_attributes   => uri_attributes,
          :uri_message      => uri_message,
          :userid           => @userid
        )
      end

      it "creates the proper button" do
        expect(described_class.count).to eq(1)
        expect(@button.uri_path).to eq('/System/Process/Automation')
        expect(@button.applies_to_id).to eq(@target_id)
        expect(@button.uri_object_name).to eq(@ae_name)
        @ae_attributes.each { |key, value| expect(@button.uri_attributes[key]).to eq(value.to_s) }

        # These attributes are not longer stored with the button
        expect(@button.uri_attributes['User::user']).to be_nil
        expect(@button.uri_attributes['MiqServer::miq_server']).to be_nil
      end

      context "when invoking for a particular VM" do
        before do
          MiqRegion.seed
          @vm    = FactoryBot.create(:vm_vmware)
          @user2 = FactoryBot.create(:user_with_group)
          EvmSpecHelper.local_miq_server(:is_master => true, :zone => Zone.seed)
        end

        it "calls automate without saved User and MiqServer" do
          User.with_user(@user2) { @button.invoke(@vm) }

          expect(MiqQueue.count).to eq(1)
          q = MiqQueue.first
          expect(q.class_name).to eq("MiqAeEngine")
          expect(q.method_name).to eq("deliver")
          expect(q.role).to eq("automate")
          expect(q.zone).to eq("default")
          expect(q.priority).to eq(MiqQueue::HIGH_PRIORITY)
          a = q.args
          expect(a).to be_kind_of(Array)
          h = a.first
          expect(h).to be_kind_of(Hash)
          expect(h[:user_id]).to eq(@user2.id)
          expect(h[:object_type]).to eq(@vm.class.base_class.name)
          expect(h[:object_id]).to eq(@vm.id)
          expect(h[:attrs]).to include(@ae_attributes)
          expect(h[:instance_name]).to eq(@ae_name)
        end
      end
    end
  end

  it ".buttons_for" do
    vm         = FactoryBot.create(:vm_vmware)
    vm_other   = FactoryBot.create(:vm_vmware)
    button1all = FactoryBot.create(:custom_button,
                                    :applies_to  => vm.class,
                                    :name        => "foo",
                                    :description => "foo foo")

    button1vm  = FactoryBot.create(:custom_button,
                                    :applies_to  => vm,
                                    :name        => "bar",
                                    :description => "bar bar")

    button2vm  = FactoryBot.create(:custom_button,
                                    :applies_to  => vm,
                                    :name        => "foo",
                                    :description => "foo foo")

    expect(described_class.buttons_for(Host)).to eq([])
    expect(described_class.buttons_for(Vm)).to eq([button1all])
    expect(described_class.buttons_for(vm)).to  match_array([button1vm, button2vm])
    expect(described_class.buttons_for(vm_other)).to eq([])
  end

  it "#save" do
    ra     = FactoryBot.create(:resource_action, :ae_namespace => 'SYSTEM', :ae_class => 'PROCESS', :ae_message => 'create')
    button = FactoryBot.create(:custom_button, :name => "My test button", :applies_to => Vm, :resource_action => ra)
    button.save

    ra.ae_message = "new message"
    button.save

    expect(button.reload.resource_action.ae_message).to eq('new message')
  end

  context "validates uniqueness" do
    before do
      @vm = FactoryBot.create(:vm_vmware)
      @default_name = @default_description = "boom"
    end

    it "applies_to_class" do
      button_for_all_vms = FactoryBot.create(:custom_button,
                                              :applies_to_class => 'Vm',
                                              :name             => @default_name,
                                              :description      => @default_description)
      expect(button_for_all_vms).to be_valid

      new_host_button = described_class.new(
        :applies_to_class => 'Host',
        :name             => @default_name,
        :description      => @default_description)
      expect(new_host_button).to be_valid

      dup_vm_button = described_class.new(
        :applies_to_class => 'Vm',
        :name             => @default_name,
        :description      => @default_description)
      expect(dup_vm_button).not_to be_valid

      dup_vm_name_button = described_class.new(
        :applies_to_class => 'Vm',
        :name             => @default_name,
        :description      => "hello world")
      expect(dup_vm_name_button).not_to be_valid

      dup_vm_desc_button = described_class.new(
        :applies_to_class => 'Vm',
        :name             => "hello",
        :description      => @default_description)
      expect(dup_vm_desc_button).not_to be_valid

      new_vm_button = described_class.new(
        :applies_to_class => 'Vm',
        :name             => "hello",
        :description      => "hello world")
      expect(new_vm_button).to be_valid
    end

    it "applies_to_instance" do
      vm_other = FactoryBot.create(:vm_vmware)

      button_for_single_vm = FactoryBot.create(:custom_button,
                                                :applies_to  => @vm,
                                                :name        => @default_name,
                                                :description => @default_description)
      expect(button_for_single_vm).to be_valid

      # For same VM
      dup_vm_button = described_class.new(
        :applies_to  => @vm,
        :name        => @default_name,
        :description => @default_description)
      expect(dup_vm_button).not_to be_valid

      dup_vm_name_button = described_class.new(
        :applies_to  => @vm,
        :name        => @default_name,
        :description => "hello world")
      expect(dup_vm_name_button).not_to be_valid

      dup_vm_desc_button = described_class.new(
        :applies_to  => @vm,
        :name        => "hello",
        :description => @default_description)
      expect(dup_vm_desc_button).not_to be_valid

      new_vm_button = described_class.new(
        :applies_to  => @vm,
        :name        => "hello",
        :description => "hello world")
      expect(new_vm_button).to be_valid

      # For other VM
      dup_vm_button = described_class.new(
        :applies_to  => vm_other,
        :name        => @default_name,
        :description => @default_description)
      expect(dup_vm_button).to be_valid

      dup_vm_name_button = described_class.new(
        :applies_to  => vm_other,
        :name        => @default_name,
        :description => "hello world")
      expect(dup_vm_name_button).to be_valid

      dup_vm_desc_button = described_class.new(
        :applies_to  => vm_other,
        :name        => "hello",
        :description => @default_description)
      expect(dup_vm_desc_button).to be_valid

      new_vm_button = described_class.new(
        :applies_to  => vm_other,
        :name        => "hello",
        :description => "hello world")
      expect(new_vm_button).to be_valid
    end
  end

  describe "#expanded_serializable_hash" do
    let(:test_button) { described_class.new(:resource_action => resource_action) }
    let(:expected_hash) do
      {
        "id"                    => nil,
        "guid"                  => nil,
        "description"           => nil,
        "disabled_text"         => nil,
        "enablement_expression" => nil,
        "applies_to_class"      => nil,
        "options"               => {},
        "userid"                => nil,
        "wait_for_complete"     => nil,
        "created_on"            => nil,
        "updated_on"            => nil,
        "name"                  => nil,
        "visibility"            => nil,
        "visibility_expression" => nil,
        "applies_to_id"         => nil
      }
    end

    context "when a resource action exists" do
      let(:resource_action) { ResourceAction.new }

      before do
        allow(resource_action).to receive(:serializable_hash).and_return("resource_action_hash")
      end

      it "returns the button as a serializable hash with the resource action serialized hash" do
        expect(test_button.expanded_serializable_hash).to eq(
          expected_hash.merge("guid" => test_button.guid, :resource_action => "resource_action_hash")
        )
      end
    end

    context "when a resource action does not exist" do
      let(:resource_action) { nil }

      it "returns the button as a serializable hash" do
        expect(test_button.expanded_serializable_hash).to eq(expected_hash.merge("guid" => test_button.guid))
      end
    end
  end

  it "#copy" do
    service_template1 = FactoryBot.create(:service_template)
    service_template2 = FactoryBot.create(:service_template)
    button = FactoryBot.create(:custom_button, :applies_to => service_template1)
    expect { button.copy(:applies_to => service_template2) }.to(change { CustomButton.count }.by(1))
  end

  describe "publish custom button event" do
    let(:vm)              { FactoryBot.create(:vm_vmware) }
    let(:vm2)             { FactoryBot.create(:vm_vmware) }
    let(:vm3)             { FactoryBot.create(:vm_vmware) }
    let(:user)            { FactoryBot.create(:user_with_group) }
    let(:resource_action) { FactoryBot.create(:resource_action, :ae_namespace => 'SYSTEM', :ae_class => 'PROCESS', :ae_instance => 'Request') }
    let(:custom_button)   { FactoryBot.create(:custom_button, :applies_to => vm.class, :resource_action => resource_action) }

    before do
      MiqRegion.seed
      EvmSpecHelper.local_miq_server(:is_master => true, :zone => Zone.seed)
    end

    %i(invoke invoke_async).each do |method|
      describe "##{method}", "publishes CustomButtonEvent(s)" do
        it "with a single VM" do
          Timecop.freeze(Time.now.utc) do
            User.with_user(user) { custom_button.send(method, vm, 'UI') }
            expect(CustomButtonEvent.first.timestamp).to be_within(0.01).of(Time.now.utc)
          end

          expect(CustomButtonEvent.count).to eq(1)
          expect(CustomButtonEvent.first).to have_attributes(
            :source      => 'UI',
            :target_id   => vm.id,
            :target_type => 'VmOrTemplate',
            :type        => 'CustomButtonEvent',
            :event_type  => 'button.trigger.start',
            :user_id     => user.id,
            :full_data   => a_hash_including(:automate_entry_point => "/SYSTEM/PROCESS/Request")
          )
        end

        describe "multiple vms" do
          it "with an array" do
            Timecop.freeze(Time.now.utc) do
              User.with_user(user) { custom_button.send(method, [vm, vm2, vm3], 'UI') }
              expect(CustomButtonEvent.first.timestamp).to be_within(0.01).of(Time.now.utc)
            end

            expect(CustomButtonEvent.count).to eq(3)
            expect(CustomButtonEvent.find_by(:target_id => vm.id, :target_type => "VmOrTemplate", :source => 'UI')).to have_attributes(
              :type        => 'CustomButtonEvent',
              :event_type  => 'button.trigger.start',
              :user_id     => user.id,
              :full_data   => a_hash_including(:automate_entry_point => "/SYSTEM/PROCESS/Request")
            )
          end

          it "with an ActiveRecord::Relation" do
            vm && vm2 && vm3
            Timecop.freeze(Time.now.utc) do
              User.with_user(user) { custom_button.send(method, Vm.all, 'UI') }
              expect(CustomButtonEvent.first.timestamp).to be_within(0.01).of(Time.now.utc)
            end

            expect(CustomButtonEvent.count).to eq(3)
            expect(CustomButtonEvent.find_by(:target_id => vm.id, :target_type => "VmOrTemplate", :source => 'UI')).to have_attributes(
              :type        => 'CustomButtonEvent',
              :event_type  => 'button.trigger.start',
              :user_id     => user.id,
              :full_data   => a_hash_including(:automate_entry_point => "/SYSTEM/PROCESS/Request")
            )
          end
        end
      end
    end

    describe "publish event" do
      context "with blank args" do
        it "resource action calls automate_queue_hash" do
          expect(resource_action).to receive(:automate_queue_hash).with(vm, {}, user).and_return(:username => "foo")

          User.with_user(user) { custom_button.publish_event('UI', vm) }
        end
      end

      context "with args" do
        it "resource action doesn't call automate_queue_hash" do
          expect(resource_action).not_to receive(:automate_queue_hash)

          User.with_user(user) { custom_button.publish_event('UI', vm, :username => "foo") }
        end
      end
    end
  end
end

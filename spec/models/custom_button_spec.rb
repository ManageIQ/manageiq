describe CustomButton do
  context "with no buttons" do

    describe '#evaluate_enablement_expression_for' do
      let(:miq_expression) { MiqExpression.new('EQUAL' => {'field' => 'Vm-name', 'value' => 'vm_1'}) }
      let(:vm)             { FactoryGirl.create(:vm_vmware, :name => 'vm_1') }
      let(:custom_button) do
        FactoryGirl.create(:custom_button, :applies_to => vm.class, :name => "foo", :description => "foo foo")
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
        @button = FactoryGirl.create(:custom_button,
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
          @vm    = FactoryGirl.create(:vm_vmware)
          @user2 = FactoryGirl.create(:user_with_group)
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
    vm         = FactoryGirl.create(:vm_vmware)
    vm_other   = FactoryGirl.create(:vm_vmware)
    button1all = FactoryGirl.create(:custom_button,
                                    :applies_to  => vm.class,
                                    :name        => "foo",
                                    :description => "foo foo")

    button1vm  = FactoryGirl.create(:custom_button,
                                    :applies_to  => vm,
                                    :name        => "bar",
                                    :description => "bar bar")

    button2vm  = FactoryGirl.create(:custom_button,
                                    :applies_to  => vm,
                                    :name        => "foo",
                                    :description => "foo foo")

    expect(described_class.buttons_for(Host)).to eq([])
    expect(described_class.buttons_for(Vm)).to eq([button1all])
    expect(described_class.buttons_for(vm)).to  match_array([button1vm, button2vm])
    expect(described_class.buttons_for(vm_other)).to eq([])
  end

  it "#save" do
    ra     = FactoryGirl.create(:resource_action, :ae_namespace => 'SYSTEM', :ae_class => 'PROCESS', :ae_message => 'create')
    button = FactoryGirl.create(:custom_button, :name => "My test button", :applies_to => Vm, :resource_action => ra)
    button.save

    ra.ae_message = "new message"
    button.save

    expect(button.reload.resource_action.ae_message).to eq('new message')
  end

  context "validates uniqueness" do
    before do
      @vm = FactoryGirl.create(:vm_vmware)
      @default_name = @default_description = "boom"
    end

    it "applies_to_class" do
      button_for_all_vms = FactoryGirl.create(:custom_button,
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
      vm_other = FactoryGirl.create(:vm_vmware)

      button_for_single_vm = FactoryGirl.create(:custom_button,
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
        "options"               => nil,
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
          expected_hash.merge(:resource_action => "resource_action_hash")
        )
      end
    end

    context "when a resource action does not exist" do
      let(:resource_action) { nil }

      it "returns the button as a serializable hash" do
        expect(test_button.expanded_serializable_hash).to eq(expected_hash)
      end
    end
  end

  it "#copy" do
    service_template1 = FactoryGirl.create(:service_template)
    service_template2 = FactoryGirl.create(:service_template)
    button = FactoryGirl.create(:custom_button, :applies_to => service_template1)
    expect { button.copy(:applies_to => service_template2) }.to change { CustomButton.count }.by(1)
  end

  context do
    let(:vm)              { FactoryGirl.create(:vm_vmware) }
    let(:user)            { FactoryGirl.create(:user_with_group) }
    let(:resource_action) { FactoryGirl.create(:resource_action, :ae_namespace => 'SYSTEM', :ae_class => 'PROCESS', :ae_instance => 'Request') }
    let(:custom_button)   { FactoryGirl.create(:custom_button, :applies_to => vm.class, :resource_action => resource_action) }

    before do
      EvmSpecHelper.local_miq_server(:is_master => true, :zone => Zone.seed)
    end

    %i(invoke invoke_async).each do |method|
      describe "##{method}" do
        it "publishes CustomButtonEvent" do
          User.with_user(user) { custom_button.send(method, vm, 'UI') }

          expect(CustomButtonEvent.count).to eq(1)
          expect(CustomButtonEvent.first).to have_attributes(
            :source      => 'UI',
            :target_id   => vm.id,
            :target_type => 'VmOrTemplate',
            :type        => 'CustomButtonEvent',
            :event_type  => 'button.trigger.start',
            :user_id     => user.id
          )
          expect(CustomButtonEvent.first[:full_data]).to include(
            :automate_entry_point => "/SYSTEM/PROCESS/Request"
          )
        end
      end
    end
  end
end

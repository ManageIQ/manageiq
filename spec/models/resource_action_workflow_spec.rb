describe ResourceActionWorkflow do
  let(:admin) { FactoryGirl.create(:user_with_group) }
  context "#create" do
    before(:each) do
      @dialog       = FactoryGirl.create(:dialog, :label => 'dialog')
      @dialog_tab   = FactoryGirl.create(:dialog_tab, :label => 'tab')
      @dialog_group = FactoryGirl.create(:dialog_group, :label => 'group')
      @dialog_field = FactoryGirl.create(:dialog_field_text_box, :label => 'field 1', :name => 'field_1')
      @dialog_field2 = FactoryGirl.create(:dialog_field_text_box, :label => 'field 2', :name => 'field_2')

      @dialog_tab.dialog_groups << @dialog_group
      @dialog_group.dialog_fields << @dialog_field
      @dialog_group.dialog_fields << @dialog_field2
      @dialog.dialog_tabs << @dialog_tab

      @resource_action = FactoryGirl.create(:resource_action, :action => "Provision", :dialog => @dialog)
    end

    it "new from resource_action" do
      @wf = ResourceActionWorkflow.new({}, admin, @resource_action)
      values = @wf.create_values_hash
      expect(values.fetch_path(:workflow_settings, :resource_action_id)).to eq(@resource_action.id)
      expect(@wf.dialog.id).to eq(@dialog.id)
    end

    it "new from hash" do
      nh = {:workflow_settings => {:resource_action_id => @resource_action.id}}
      @wf = ResourceActionWorkflow.new(nh, admin, nil)
      values = @wf.create_values_hash
      expect(values.fetch_path(:workflow_settings, :resource_action_id)).to eq(@resource_action.id)
      expect(@wf.dialog.id).to eq(@dialog.id)
    end

    it "load default_value" do
      @dialog_field.update_attribute(:default_value, "testing default")
      @wf = ResourceActionWorkflow.new({}, admin, @resource_action)
      expect(@wf.value(@dialog_field.name)).to eq("testing default")
      df = @wf.dialog_field(@dialog_field.name)
      expect(df.value).to eq("testing default")
    end

    it "field_name_exists?" do
      expect(@dialog.field_name_exist?('field_1')).to  be_truthy
      expect(@dialog.field_name_exist?('field_11')).to be_falsey
      expect(@dialog.field_name_exist?('FIELD_11')).to be_falsey
      expect(@dialog.field_name_exist?(:field_11)).to  be_falsey
    end

    context "with workflow" do
      before(:each) do
        @wf = ResourceActionWorkflow.new({}, admin, @resource_action)
      end

      it "set_value" do
        @wf.set_value(:field_1, "test_var_1")
        expect(@wf.value(:field_1)).to eq("test_var_1")
      end

      it "#validate" do
        expect { @wf.validate(nil) }.to_not raise_error
      end
    end

    context "#submit_request" do
      subject { ResourceActionWorkflow.new({}, admin, resource_action, :target => target) }
      let(:resource_action) { @resource_action }

      context "with request class" do
        let(:target) { FactoryGirl.create(:service) }

        it "creates requests" do
          EvmSpecHelper.local_miq_server
          expect(subject).to receive(:make_request).and_call_original
          expect(AuditEvent).to receive(:success).with(
            :event        => "service_reconfigure_request_created",
            :target_class => "Service",
            :userid       => admin.userid,
            :message      => "Service Reconfigure requested by <#{admin.userid}> for Service:[#{target.id}]"
          )
          response = subject.submit_request
          expect(response).to include(:errors => [])
        end
      end

      context "without request class" do
        subject { ResourceActionWorkflow.new({}, admin, resource_action, :target => target) }
        let(:resource_action) { @resource_action }

        let(:target) { FactoryGirl.create(:vm_vmware) }

        it "calls automate" do
          EvmSpecHelper.local_miq_server
          expect(subject).not_to receive(:make_request)
          expect_any_instance_of(ResourceAction).to receive(:deliver_to_automate_from_dialog).and_call_original
          expect(MiqAeEngine).to receive(:deliver_queue) # calls into automate
          expect(AuditEvent).not_to receive(:success)
          response = subject.submit_request
          expect(response).to eq(:errors => [])
        end
      end

      context "with custom button request" do
        let(:target) { FactoryGirl.build(:service) }
        let(:resource_action) do
          @resource_action.tap do |ra|
            ra.update_attributes(:resource => FactoryGirl.create(:custom_button, :applies_to_class => target.class.name))
          end
        end

        it "calls automate" do
          expect(subject).not_to receive(:make_request)
          expect_any_instance_of(ResourceAction).to receive(:deliver_to_automate_from_dialog)

          subject.submit_request
        end
      end
    end
  end

  describe "#initialize #load_dialog" do
    let(:resource_action) { instance_double("ResourceAction", :id => 123, :dialog => dialog) }
    let(:dialog) { instance_double("Dialog", :id => 321) }
    let(:values) { "the values" }
    let(:options) { {:display_view_only => display_view_only} }

    before do
      allow(ResourceAction).to receive(:find).and_return(resource_action)
      allow(dialog).to receive(:init_fields_with_values).with(values)
      allow(dialog).to receive(:init_fields_with_values_for_request).with(values)
      allow(dialog).to receive(:target_resource=)
    end

    context "when the options set display_view_only to true" do
      let(:display_view_only) { true }

      it "calls init_fields_with_values_for_request" do
        expect(dialog).to receive(:init_fields_with_values_for_request).with(values)
        ResourceActionWorkflow.new(values, nil, resource_action, options)
      end
    end

    context "when the options set display_view_only to false" do
      let(:display_view_only) { false }

      it "calls init_fields_with_values" do
        expect(dialog).to receive(:init_fields_with_values).with(values)
        ResourceActionWorkflow.new(values, nil, resource_action, options)
      end
    end
  end
end

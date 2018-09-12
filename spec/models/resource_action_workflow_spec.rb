describe ResourceActionWorkflow do
  let(:admin) { FactoryGirl.create(:user_with_group) }

  context "#create" do
    before do
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

    it "field_name_exists?" do
      expect(@dialog.field_name_exist?('field_1')).to  be_truthy
      expect(@dialog.field_name_exist?('field_11')).to be_falsey
      expect(@dialog.field_name_exist?('FIELD_11')).to be_falsey
      expect(@dialog.field_name_exist?(:field_11)).to  be_falsey
    end

    context "with workflow" do
      let(:data) { {"parameters" => {"field_1" => "new_value"}} }
      before do
        @wf = ResourceActionWorkflow.new({}, admin, @resource_action)
      end

      it "set_value" do
        @wf.set_value(:field_1, "test_var_1")
        expect(@wf.value(:field_1)).to eq("test_var_1")
      end

      it "#validate" do
        expect { @wf.validate(nil) }.to_not raise_error
      end

      it "#update_dialog_field_values" do
        @wf.update_dialog_field_values(data)

        expect(dialog_fields(@dialog)).to eq("field_1" => "new_value", "field_2" => nil)
      end
    end

    context "#submit_request" do
      subject { ResourceActionWorkflow.new({}, admin, resource_action, :target => target) }
      let(:resource_action) { @resource_action }
      context "with blank data" do
        let(:data) { {} }

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
            expect(dialog_fields(@dialog)).to eq("field_1" => nil, "field_2" => nil)
            response = subject.submit_request(data)
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
            expect(dialog_fields(@dialog)).to eq("field_2" => nil, "field_1" => nil)
            response = subject.submit_request(data)
            expect(response).to eq(:errors => [])
          end
        end

        context "with custom button request" do
          let(:target)  { FactoryGirl.build(:service) }
          let(:options) { {} }
          let(:resource_action) do
            @resource_action.tap do |ra|
              ra.update_attributes(:resource => FactoryGirl.create(:custom_button, :applies_to_class => target.class.name, :options => options))
            end
          end

          it "calls automate" do
            expect(subject).not_to receive(:make_request)
            expect_any_instance_of(ResourceAction).to receive(:deliver_to_automate_from_dialog)

            subject.submit_request(data)
            expect(dialog_fields(@dialog)).to eq("field_1" => nil, "field_2" => nil)
          end

          it "calls automate with miq_task" do
            options[:open_url] = true
            allow(resource_action).to(receive(:deliver_to_automate_from_dialog))
            allow(subject).to(receive(:load_resource_action)).and_return(resource_action)

            result   = subject.submit_request
            miq_task = MiqTask.find(result[:task_id])
            expect(miq_task.state).to(eq(MiqTask::STATE_QUEUED))
            expect(miq_task.status).to(eq(MiqTask::STATUS_OK))
            expect(miq_task.message).to(eq('MiqTask has been queued.'))
          end
        end
      end

      context "with non-blank data" do
        let(:data) { {"parameters" => {"field_1" => "new_value"}} }

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
            response = subject.submit_request(data)
            expect(dialog_fields(@dialog)).to eq("field_1" => "new_value", "field_2" => nil)
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
            response = subject.submit_request(data)
            expect(dialog_fields(@dialog)).to eq("field_2" => nil, "field_1" => "new_value")
            expect(response).to eq(:errors => [])
          end
        end

        context "with custom button request" do
          let(:target)  { FactoryGirl.build(:service) }
          let(:options) { {} }
          let(:resource_action) do
            @resource_action.tap do |ra|
              ra.update_attributes(:resource => FactoryGirl.create(:custom_button, :applies_to_class => target.class.name, :options => options))
            end
          end

          it "calls automate" do
            expect(subject).not_to receive(:make_request)
            expect_any_instance_of(ResourceAction).to receive(:deliver_to_automate_from_dialog)

            subject.submit_request(data)
            expect(dialog_fields(@dialog)).to eq("field_2" => nil, "field_1" => "new_value")
          end

          it "calls automate with miq_task" do
            options[:open_url] = true
            allow(resource_action).to(receive(:deliver_to_automate_from_dialog))
            allow(subject).to(receive(:load_resource_action)).and_return(resource_action)

            result   = subject.submit_request
            miq_task = MiqTask.find(result[:task_id])
            expect(miq_task.state).to(eq(MiqTask::STATE_QUEUED))
            expect(miq_task.status).to(eq(MiqTask::STATUS_OK))
            expect(miq_task.message).to(eq('MiqTask has been queued.'))
          end
        end
      end
    end
  end

  describe "#initialize #load_dialog" do
    let(:resource_action) { instance_double("ResourceAction", :id => 123, :dialog => dialog) }
    let(:dialog) { instance_double("Dialog", :id => 321) }
    let(:values) { "the values" }

    before do
      allow(ResourceAction).to receive(:find).and_return(resource_action)
      allow(dialog).to receive(:load_values_into_fields).with(values)
      allow(dialog).to receive(:initialize_value_context).with(values)
      allow(dialog).to receive(:init_fields_with_values_for_request).with(values)
      allow(dialog).to receive(:target_resource=)
    end

    context "when the options set display_view_only to true" do
      let(:options) { {:display_view_only => true} }

      it "calls init_fields_with_values_for_request" do
        expect(dialog).to receive(:init_fields_with_values_for_request).with(values)
        ResourceActionWorkflow.new(values, nil, resource_action, options)
      end
    end

    context "when the options are set to a refresh request" do
      let(:options) { {:refresh => true} }

      it "loads the values into fields" do
        expect(dialog).to receive(:load_values_into_fields).with(values)
        ResourceActionWorkflow.new(values, nil, resource_action, options)
      end
    end

    context "when the options are set to a reconfigure request" do
      let(:options) { {:reconfigure => true} }

      it "initializes the fields with the given values" do
        expect(dialog).to receive(:initialize_with_given_values).with(values)
        ResourceActionWorkflow.new(values, nil, resource_action, options)
      end
    end

    context "when the options are set to a submit workflow request" do
      let(:options) { {:submit_workflow => true} }

      it "loads the values into fields" do
        expect(dialog).to receive(:load_values_into_fields).with(values)
        ResourceActionWorkflow.new(values, nil, resource_action, options)
      end
    end

    context "when the options are set to a provision workflow request" do
      let(:options) { {:provision_workflow => true} }

      it "initializes the value context and then loads the values into fields" do
        expect(dialog).to receive(:initialize_value_context).with(values).ordered
        expect(dialog).to receive(:load_values_into_fields).with(values, false).ordered
        ResourceActionWorkflow.new(values, nil, resource_action, options)
      end
    end

    context "when neither display_view_only nor refresh are true" do
      let(:options) { {} }

      it "initializes the value context" do
        expect(dialog).to receive(:initialize_value_context).with(values)
        ResourceActionWorkflow.new(values, nil, resource_action, options)
      end
    end
  end

  def dialog_fields(dialog)
    dialog.dialog_fields.map { |df| [df.name, df.value] }.to_h
  end
end

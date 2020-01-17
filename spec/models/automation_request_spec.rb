RSpec.describe AutomationRequest do
  let(:admin) { FactoryBot.create(:user, :role => "admin") }
  before do
    MiqRegion.seed
    allow(MiqServer).to receive(:my_zone).and_return(Zone.seed.name)
    @zone        = FactoryBot.create(:zone, :name => "fred")
    @approver    = FactoryBot.create(:user_miq_request_approver)

    @version     = 1
    @ae_instance = "IIII"
    @ae_message  = "MMMM"
    @ae_var1     = "vvvv"
    @ae_var2     = "wwww"
    @ae_var3     = "xxxx"
    @uri_parts   = {'instance' => @ae_instance.to_s, 'message' => @ae_message.to_s}
    @parameters  = {'var1' => @ae_var1.to_s, 'var2' => @ae_var2.to_s, 'var3' => @ae_var3.to_s}
  end

  it ".request_task_class" do
    expect(AutomationRequest.request_task_class).to eq(AutomationTask)
  end

  context ".create_from_ws" do
    it "with empty requester string" do
      ar = AutomationRequest.create_from_ws(@version, admin, @uri_parts, @parameters, {})
      expect(ar).to be_kind_of(AutomationRequest)

      expect(ar).to eq(AutomationRequest.first)
      expect(ar.request_state).to eq("pending")
      expect(ar.status).to eq("Ok")
      expect(ar.approval_state).to eq("pending_approval")
      expect(ar.userid).to eq(admin.userid)
      expect(ar.options[:message]).to eq(@ae_message)
      expect(ar.options[:instance_name]).to eq(@ae_instance)
      expect(ar.options[:user_id]).to eq(admin.id)
      expect(ar.options[:attrs][:var1]).to eq(@ae_var1)
      expect(ar.options[:attrs][:var2]).to eq(@ae_var2)
      expect(ar.options[:attrs][:var3]).to eq(@ae_var3)
      expect(ar.options[:attrs][:userid]).to eq(admin.userid)
      expect(ar.options[:schedule_type]).to eq("immediately")
      expect(ar.options[:schedule_time]).to eq(nil)
      expect(ar.options[:attrs].keys).to eq([:var1, :var2, :var3, :userid])
    end

    it "with object in parameters" do
      parameters = {'var1' => @ae_var1.to_s, 'var2' => @ae_var2.to_s, 'var3' => @ae_var3.to_s, 'VmOrTemplate::vm' => 10}
      ar = AutomationRequest.create_from_ws(@version, admin, @uri_parts, parameters, {})
      expect(ar.options[:attrs].keys).to include("VmOrTemplate::vm")
    end

    context "with schedule" do
      it "with schedule_time param" do
        @parameters['schedule_time'] = "2019-08-14 17:41:06 UTC"
        ar = AutomationRequest.create_from_ws(@version, admin, @uri_parts, @parameters, {})

        expect(ar.options[:schedule_type]).to eq("schedule")
        expect(ar.options[:schedule_time]).to be_within(1.second).of Time.zone.parse("2019-08-14 17:41:06 UTC")
      end

      it "immediately" do
        ar = AutomationRequest.create_from_ws(@version, admin, @uri_parts, @parameters, {})

        expect(ar.options[:schedule_type]).to eq("immediately")
      end
    end

    it 'does not downcase and stringify objects in the parameters hash' do
      @object_parameters = {'VmOrTemplate::vm' => 10, 'var2' => @ae_var2.to_s, 'var3' => @ae_var3.to_s}
      ar = AutomationRequest.create_from_ws(@version, admin, @uri_parts, @object_parameters, {})
      expect(ar.options[:attrs]).to include("VmOrTemplate::vm" => 10, :var2 => @ae_var2.to_s)
      expect(@object_parameters).to include("VmOrTemplate::vm" => 10)
    end

    it "does not allow overriding userid who is NOT in the database" do
      user_name = 'oleg'

      expect do
        AutomationRequest.create_from_ws(@version, admin, @uri_parts, @parameters, "user_name" => user_name.to_s)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "with requester string overriding userid who is in the database" do
      ar = AutomationRequest.create_from_ws(@version, admin,
                                            @uri_parts, @parameters,
                                            "user_name" => @approver.userid.to_s)
      expect(ar).to be_kind_of(AutomationRequest)

      expect(ar).to eq(AutomationRequest.first)
      expect(ar.request_state).to eq("pending")
      expect(ar.status).to eq("Ok")
      expect(ar.approval_state).to eq("pending_approval")
      expect(ar.userid).to eq(@approver.userid)
      expect(ar.options[:message]).to eq(@ae_message)
      expect(ar.options[:instance_name]).to eq(@ae_instance)
      expect(ar.options[:user_id]).to eq(@approver.id)
      expect(ar.options[:attrs][:var1]).to eq(@ae_var1)
      expect(ar.options[:attrs][:var2]).to eq(@ae_var2)
      expect(ar.options[:attrs][:var3]).to eq(@ae_var3)
      expect(ar.options[:attrs][:userid]).to eq(@approver.userid)
    end

    it "with requester string overriding userid AND auto_approval" do
      FactoryBot.create(:user_admin, :userid => 'admin')
      ar = AutomationRequest.create_from_ws(@version, admin,
                                            @uri_parts, @parameters,
                                            "user_name" => @approver.userid.to_s, 'auto_approve' => 'true')
      expect(ar).to be_kind_of(AutomationRequest)

      expect(ar).to eq(AutomationRequest.first)
      expect(ar.request_state).to eq("pending")
      expect(ar.status).to eq("Ok")
      expect(ar.approval_state).to eq("approved")
      expect(ar.userid).to eq(@approver.userid)
      expect(ar.options[:message]).to eq(@ae_message)
      expect(ar.options[:instance_name]).to eq(@ae_instance)
      expect(ar.options[:user_id]).to eq(@approver.id)
      expect(ar.options[:attrs][:var1]).to eq(@ae_var1)
      expect(ar.options[:attrs][:var2]).to eq(@ae_var2)
      expect(ar.options[:attrs][:var3]).to eq(@ae_var3)
      expect(ar.options[:attrs][:userid]).to eq(@approver.userid)
    end
  end

  context ".create_from_scheduled_task" do
    let(:admin) { FactoryBot.create(:user_miq_request_approver) }
    before { FactoryBot.create(:user_admin, :userid => 'admin') }

    it "with prescheduled task" do
      ar = described_class.create_from_scheduled_task(admin, @uri_parts, @parameters)
      expect(ar).to be_kind_of(AutomationRequest)
      expect(ar).to eq(AutomationRequest.first)
      expect(ar).to have_attributes(
        "request_state"  => "pending",
        "status"         => "Ok",
        "approval_state" => "approved",
        "userid"         => admin.userid.to_s,
      )
      expect(ar.options).to include(
        :namespace  => "SYSTEM",
        :class_name => "PROCESS",
        :user_id    => admin.id
      )
    end

    it "allows /System/Process to be passed in" do
      uri_parts = @uri_parts.merge(:namespace => "/System", :class_name => "Process")
      ar = AutomationRequest.create_from_scheduled_task(admin, uri_parts, @parameters)
      expect(ar.options).to include(
        :namespace  => "SYSTEM",
        :class_name => "PROCESS"
      )
    end

    it "locks scheduled tasks to /System/Process when other namespaces and class_names are passed in" do
      uri_parts = @uri_parts.merge(:namespace => "/Test", :class_name => "TestClass")
      ar = AutomationRequest.create_from_scheduled_task(admin, uri_parts, @parameters)
      expect(ar.options).to include(
        :namespace  => "SYSTEM",
        :class_name => "PROCESS"
      )
    end

    it "locks class_name to Process when something else is passed in" do
      uri_parts = @uri_parts.merge(:class_name => "TestClass")
      ar = AutomationRequest.create_from_scheduled_task(admin, uri_parts, @parameters)
      expect(ar.options).to include(
        :class_name => "PROCESS"
      )
    end

    it "locks namespace to System when something else is passed in" do
      uri_parts = @uri_parts.merge(:namespace => "/Test")
      ar = AutomationRequest.create_from_scheduled_task(admin, uri_parts, @parameters)
      expect(ar.options).to include(
        :namespace  => "SYSTEM"
      )
    end

    it "only allow parameters that are stringified" do
      parameters_sym = {:var1 => @ae_var1.to_s, :var2 => @ae_var2.to_s, :var3 => @ae_var3.to_s}
      expect(AutomationRequest).to receive(:create_from_ws).with(anything, anything, anything, @parameters, anything)
      AutomationRequest.create_from_scheduled_task(admin, @uri_parts, parameters_sym)
    end
  end

  context "#approve" do
    context "an unapproved request with a single approver" do
      before do
        @ar = AutomationRequest.create_from_ws(@version, admin, @uri_parts, @parameters, {})
        @reason = "Why Not?"
      end

      it "updates approval_state" do
        @ar.approve(@approver, @reason)
        expect(@ar.reload.approval_state).to eq("approved")
      end

      it "calls #call_automate_event_queue('request_approved')" do
        expect(@ar).to receive(:call_automate_event_queue).with('request_approved').once
        @ar.approve(@approver, @reason)
      end

      it "calls #execute" do
        expect(@ar).to receive(:execute).once
        @ar.approve(@approver, @reason)
      end
    end
  end

  describe "#make_request" do
    it "creates and update a request" do
      expect(AuditEvent).not_to receive(:success)
      values = {}

      request = described_class.make_request(nil, values, admin)

      expect(request).to be_valid
      expect(request).to be_a_kind_of(AutomationRequest)
      expect(request.request_type).to eq("automation")
      expect(request.description).to eq("Automation Task")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)
    end
  end

  context "#create_request_tasks" do
    before do
      @ar = AutomationRequest.create_from_ws(@version, admin, @uri_parts, @parameters, {})
      root = {'ae_result' => 'ok'}
      @ws = double('ws')
      allow(@ws).to receive_messages(:root => root)
      allow(@ar).to receive(:call_automate_event).and_return(@ws)

      @ar.create_request_tasks
      @ar.reload
    end

    it "should create AutomationTask" do
      expect(@ar.automation_tasks.length).to eq(1)
      expect(AutomationTask.count).to eq(1)
      expect(AutomationTask.first).to eq(@ar.automation_tasks.first)
    end
  end

  context "validate zone" do
    before do
      FactoryBot.create(:user_admin, :userid => 'admin')
      allow_any_instance_of(MiqRequest).to receive(:automate_event_failed?).and_return(false)
    end

    def deliver(zone_name)
      parameters = {'miq_zone' => zone_name.to_s,
                    'var1'     => @ae_var1.to_s,
                    'var2'     => @ae_var2.to_s,
                    'var3'     => @ae_var3.to_s}
      AutomationRequest.create_from_ws(@version, @approver, @uri_parts, parameters, 'auto_approve' => 'true')
      MiqQueue.find_by(:method_name => "create_request_tasks").deliver
    end

    def check_zone(zone_name)
      expect(MiqQueue.count).to eq(4)
      expect(MiqQueue.pluck(:zone).uniq).to eq([zone_name])
    end

    it "zone specified" do
      deliver(@zone.name)
      check_zone(@zone.name)
    end

    it "zone not specified" do
      AutomationRequest.create_from_ws(@version, @approver, @uri_parts, @parameters, 'auto_approve' => 'true')
      MiqQueue.find_by(:method_name => "create_request_tasks").deliver
      check_zone("default")
    end

    it "non existent zone specified" do
      expect { deliver("does_not_exist") }.to raise_error(ArgumentError)
    end

    it "blank zone should result in empty zone" do
      deliver("")
      check_zone(nil)
    end

    it "nil zone should result in empty zone" do
      deliver(nil)
      check_zone(nil)
    end
  end
end

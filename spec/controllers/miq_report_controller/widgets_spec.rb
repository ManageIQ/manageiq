describe ReportController do
  before(:each) do
    EvmSpecHelper.create_guid_miq_server_zone
    set_user_privileges
  end
  describe "#widget_edit" do
    let(:miq_schedule) { FactoryGirl.build(:miq_schedule, :run_at => {}, :sched_action => {}) }
    let(:new_widget) { controller.instance_variable_get(:@widget) }

    # Configuration Management/Virtual Machines/VMs with Free Space > 50% by Department report
    let(:report_id) { 100_000_000_000_01 }

    before :each do
      @previous_count_of_widgets = MiqWidget.count
      allow(controller).to receive_messages(:load_edit => true)
      allow(controller).to receive(:widget_graph_menus)
      allow(controller).to receive(:replace_right_cell)
      allow(controller).to receive(:render)
      controller.instance_variable_set(:@sb, :wtype => 'c') # chart widget
    end

    context "add new widget" do
      before :each do
        controller.instance_variable_set(:@_params, :button => "add")
      end

      context "valid attributes" do
        before :each do
          timer = ReportHelper::Timer.new('Hourly', 1, 1, 1, 1, '11/13/2015', '00')
          controller.instance_variable_set(:@edit,
                                           :schedule => miq_schedule, :new => {:title => "NewCustomWidget",
                                                                               :description => "NewCustomWidget",
                                                                               :enabled => true, :roles => ["_ALL_"],
                                                                               :groups => [],
                                                                               :timer => timer,
                                                                               :start_min => "10",
                                                                               :repfilter => report_id})
          controller.send(:widget_edit)
        end

        it "adds new widget with entered attributes" do
          expect(MiqWidget.count).to eq(@previous_count_of_widgets + 1)
          expect(new_widget.errors.count).to eq(0)
          expect(new_widget.title).to eq("NewCustomWidget")
          expect(new_widget.description).to eq("NewCustomWidget")
          expect(new_widget.enabled).to eq(true)
        end

        it "creates widget with widget.id in 'value' field from cond. of MiqExpression (in MiqSchedule.filter)" do
          expect(new_widget.id).to be_instance_of(Fixnum)
          expect(miq_schedule.filter.exp["="]["value"]).to eq(new_widget.id)
        end
      end

      context "invalid attributes" do
        before :each do
          timer = ReportHelper::Timer.new('Hourly', 1, 1, 1, 1, '11/13/2015', '00')
          controller.instance_variable_set(:@edit,
                                           :schedule => miq_schedule, :new => {:title => "",
                                                                               :description => "",
                                                                               :enabled => true, :roles => ["_ALL_"],
                                                                               :groups => [],
                                                                               :timer => timer,
                                                                               :start_min => "10",
                                                                               :repfilter => report_id})
          controller.send(:widget_edit)
        end

        it "doesn't add new widget" do
          expect(MiqWidget.count).to eq(@previous_count_of_widgets)
          expect(new_widget.errors.count).not_to eq(0)
        end
      end
    end
  end
end

describe ApplicationController, "#Timelines" do
  describe EmsInfraController do
    context "#tl_chooser" do
      before do
        @ems = FactoryGirl.create(:ems_openstack_infra)
        controller.instance_variable_set(:@tl_options,
                                         ApplicationController::Timelines::Options.new)
      end

      it "resets timeline options correctly when apply button is pressed" do
        options            = assigns(:tl_options)
        dt                 = Time.zone.now
        options.date       = ApplicationController::Timelines::DateOptions.new
        options.date.end   = dt
        options.date.start = dt

        controller.instance_variable_set(:@_params, :id => @ems.id, :tl_show => "policy_timeline")
        expect(controller).to receive(:render)

        expect(options.date[:start]).to eq(dt)
        expect(options.date[:end]).to eq(dt)

        controller.send(:tl_chooser)

        options = assigns(:tl_options)
        expect(options.date[:start]).to eq(nil)
        expect(options.date[:end]).to eq(nil)
      end

      it "sets categories for policy timelines correctly" do
        controller.instance_variable_set(:@_params,
                                         :id            => @ems.id,
                                         :tl_show       => "policy_timeline",
                                         :tl_categories => ["VM Operation"])
        expect(controller).to receive(:render)
        controller.send(:tl_chooser)
        options = assigns(:tl_options)
        expect(options.policy[:categories]).to include('VM Operation')
      end

      it "unchecking Detailed events checkbox of Timelines options should remove them from list of events" do
        controller.instance_variable_set(:@_params,
                                         :id            => @ems.id,
                                         :tl_show       => "timeline",
                                         :tl_fl_typ     => "critical",
                                         :tl_categories => ["Power Activity"])
        expect(controller).to receive(:render)
        controller.send(:tl_chooser)
        options = assigns(:tl_options)
        expect(options.management[:categories][:power][:event_groups]).to include('AUTO_FAILED_SUSPEND_VM')
        expect(options.management[:categories][:power][:event_groups]).to_not include('PowerOffVM_Task')
      end

      it "checking Detailed events checkbox of Timelines options should append them to list of events" do
        controller.instance_variable_set(:@_params,
                                         :id            => @ems.id,
                                         :tl_show       => "timeline",
                                         :tl_fl_typ     => "detail",
                                         :tl_categories => ["Power Activity"])
        expect(controller).to receive(:render)
        controller.send(:tl_chooser)
        options = assigns(:tl_options)
        expect(options.management[:categories][:power][:event_groups]).to include('PowerOffVM_Task')
        expect(options.management[:categories][:power][:event_groups]).to include('AUTO_FAILED_SUSPEND_VM')
      end
    end
  end
end

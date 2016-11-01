describe OpsController do
  context "OpsSettings::Schedules" do
    let(:user) { FactoryGirl.create(:user, :features => %w(schedule_enable schedule_disable)) }
    before do
      login_as user
    end

    context "no schedules selected" do
      before do
        silence_warnings { OpsController::Settings::Schedules::STGROOT = 'ST' }

        allow(controller).to receive(:find_checked_items).and_return([])
        expect(controller).to receive(:render)
        expect(controller).to receive(:schedule_build_list)
        expect(controller).to receive(:settings_get_info)
        expect(controller).to receive(:replace_right_cell)
      end

      it "#schedule_enable" do
        controller.schedule_enable
        flash_messages = controller.instance_variable_get(:@flash_array)
        expect(flash_messages.first).to eq(:message => "The selected Schedules were enabled", :level => :error)
      end

      it "#schedule_disable" do
        controller.schedule_disable
        flash_messages = controller.instance_variable_get(:@flash_array)
        expect(flash_messages.first).to eq(:message => "The selected Schedules were disabled", :level => :error)
      end
    end

    context "normal case" do
      before do
        server = double
        allow(server).to receive_messages(:zone_id => 1)
        allow(MiqServer).to receive(:my_server).and_return(server)

        @sch = FactoryGirl.create(:miq_schedule)
        silence_warnings { OpsController::Settings::Schedules::STGROOT = 'ST' }

        controller.params["check_#{controller.to_cid(@sch.id)}"] = '1'
        expect(controller).to receive(:render).never
        expect(controller).to receive(:schedule_build_list)
        expect(controller).to receive(:settings_get_info)
        expect(controller).to receive(:replace_right_cell)
      end

      it "doesn't update schedules that don't change" do
        # set it to disabled
        @sch.update_attribute(:enabled, false)

        # enable the schedule and save it
        controller.schedule_disable
        expect(controller.send(:flash_errors?)).not_to be_truthy

        @sch.reload

        # assert that it's disabled
        expect(@sch).not_to be_enabled
      end

      it "#schedule_enable" do
        # set it to disabled
        @sch.update_attribute(:enabled, false)

        # enable the schedule and save it
        controller.schedule_enable
        expect(controller.send(:flash_errors?)).not_to be_truthy

        @sch.reload

        # assert that it's enabled
        expect(@sch).to be_enabled
      end

      it "#schedule_disable" do
        # set it to enabled
        @sch.update_attribute(:enabled, true)

        # disable the schedule and save it
        controller.schedule_disable
        expect(controller.send(:flash_errors?)).not_to be_truthy

        @sch.reload

        # assert that it's disabled
        expect(@sch).not_to be_enabled
      end
    end

    context "schedule addition" do
      before(:each) do
        EvmSpecHelper.create_guid_miq_server_zone
        expect(controller).to receive(:render)
        @schedule = FactoryGirl.create(:miq_schedule, :userid => user.userid, :towhat => "Vm")
        @params = {
          :action      => "schedule_edit",
          :button      => "add",
          :description => "description01",
          :enabled     => "on",
          :filter_typ  => "all",
          :action_typ  => "vm",
          :timer_typ   => "Once",
          :time_zone   => "UTC",
          :start_hour  => "0",
          :start_min   => "0",
          :start_date  => 2.days.from_now.utc.strftime("%m/%d/%Y")
        }
        allow(controller).to receive(:assert_privileges)
      end

      after(:each) do
        expect(response.status).to eq(200)
      end

      it "#does not allow duplicate names when adding" do
        @params[:id] = "new"
        @params[:name] = @schedule.name
        controller.instance_variable_set(:@_params, @params)
        controller.send(:schedule_edit)
        expect(controller.send(:flash_errors?)).to be_truthy
        expect(assigns(:flash_array).first[:message]).to include("Name has already been taken")
      end

      it "#does not allow duplicate names when editing" do
        @params[:id] = @schedule.id
        @params[:name] = "schedule01"
        controller.instance_variable_set(:@_params, @params)
        FactoryGirl.create(:miq_schedule, :name => @params[:name], :userid => user.userid, :towhat => "Vm")
        controller.send(:schedule_edit)
        expect(controller.send(:flash_errors?)).to be_truthy
        expect(assigns(:flash_array).first[:message]).to include("Name has already been taken")
      end
    end
  end

  render_views
  context "OpsController::Settings" do
    let(:user) { FactoryGirl.create(:user, :features => %w(zone_edit zone_new)) }
    before do
      login_as user
    end

    context "zone addition" do
      it "#does not allow duplicate names when adding" do
        miq_server = EvmSpecHelper.local_miq_server
        MiqRegion.seed
        EvmSpecHelper.create_guid_miq_server_zone
        expect(controller).to receive(:render)
        @zone = FactoryGirl.create(:zone, :name => 'zoneName', :description => "description1")
        allow(controller).to receive(:assert_privileges)

        @params = {:id => 'new',
                   :action      => "zone_edit",
                   :button      => "add"
        }
        edit = {:new => {:name        => @zone.name,
                         :description => "description02",
                         :ntp => {}}}
        controller.instance_variable_set(:@edit, edit)
        controller.instance_variable_set(:@_params, @params)
        seed_session_trees('ops', :settings_tree)
        allow(controller).to receive(:load_edit).and_return(true)
        controller.send(:zone_edit)

        expect(controller.send(:flash_errors?)).to be_truthy
        expect(assigns(:flash_array).first[:message]).to include("Name has already been taken")
      end
    end
  end

  context "replace_right_cell" do
    before do
      miq_server = EvmSpecHelper.local_miq_server
      MiqRegion.seed
      expect(MiqRegion.my_region.zones).to eq([miq_server.zone])
    end

    it "it renders replace_right_cell" do
      controller.instance_variable_set(:@sb,
                                       :trees         => {:settings_tree => {:open_nodes => []}},
                                       :active_accord => 'active_accord',
                                       :active_tab    => 'settings_server',
                                       :active_tree   => :settings_tree)
      expect(controller).to receive(:x_active_tree_replace_cell)
      expect(controller).to receive(:replace_explorer_trees)
      expect(controller).to receive(:rebuild_toolbars)
      expect(controller).to receive(:handle_bottom_cell)
      expect(controller).to receive(:extra_js_commands)
      expect(controller).to receive(:render)
      controller.send(:replace_right_cell, {:nodetype => 'svr', :replace_trees => [:settings]})
      expect(response.status).to eq(200)
    end
  end
end

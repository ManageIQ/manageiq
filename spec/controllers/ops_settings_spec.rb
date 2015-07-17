require "spec_helper"

describe OpsController do
  context "OpsSettings::Schedules" do
    before do
      seed_specific_product_features("schedule_enable", "schedule_disable")
    end

    context "no schedules selected" do
      before do
        silence_warnings { OpsController::Settings::Schedules::STGROOT = 'ST' }

        controller.stub(:find_checked_items).and_return([])
        controller.should_receive(:render)
        controller.should_receive(:schedule_build_list)
        controller.should_receive(:settings_get_info)
        controller.should_receive(:replace_right_cell)
      end

      it "#schedule_enable" do
        controller.schedule_enable
        flash_messages = controller.instance_variable_get(:@flash_array)
        flash_messages.first.should == {:message => "No Schedules were selected to be enabled", :level => :error }
      end

      it "#schedule_disable" do
        controller.schedule_disable
        flash_messages = controller.instance_variable_get(:@flash_array)
        flash_messages.first.should == {:message => "No Schedules were selected to be disabled", :level => :error }
      end
    end

    context "normal case" do
      before do
        server = double
        server.stub(:zone_id => 1)
        MiqServer.stub(:my_server).and_return(server)

        @sch = FactoryGirl.create(:miq_schedule)
        silence_warnings { OpsController::Settings::Schedules::STGROOT = 'ST' }

        controller.params["check_#{controller.to_cid(@sch.id)}"] = '1'
        controller.should_receive(:render).never
        controller.should_receive(:schedule_build_list)
        controller.should_receive(:settings_get_info)
        controller.should_receive(:replace_right_cell)
      end

      it "doesn't update schedules that don't change" do
        # set it to disabled
        @sch.update_attribute(:enabled, false)

        # enable the schedule and save it
        controller.schedule_disable
        controller.send(:flash_errors?).should_not be_true

        @sch.reload

        # assert that it's disabled
        @sch.should_not be_enabled
      end

      it "#schedule_enable" do
        # set it to disabled
        @sch.update_attribute(:enabled, false)

        # enable the schedule and save it
        controller.schedule_enable
        controller.send(:flash_errors?).should_not be_true

        @sch.reload

        # assert that it's enabled
        @sch.should be_enabled
      end

      it "#schedule_disable" do
        # set it to enabled
        @sch.update_attribute(:enabled, true)

        # disable the schedule and save it
        controller.schedule_disable
        controller.send(:flash_errors?).should_not be_true

        @sch.reload

        # assert that it's disabled
        @sch.should_not be_enabled
      end
    end

    context "schedule additon" do
      before(:each) do
        EvmSpecHelper.create_guid_miq_server_zone
        controller.should_receive(:render)
        @schedule = FactoryGirl.create(:miq_schedule, :userid => "test", :towhat => "Vm")
        @params = {
          :action      => "vm",
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
        controller.stub(:assert_privileges)
      end

      after(:each) do
        expect(response.status).to eq(200)
      end

      it "#does not allow duplicate names when adding" do
        @params[:id] = "new"
        @params[:name] = @schedule.name
        controller.instance_variable_set(:@_params, @params)
        controller.send(:schedule_edit)
        controller.send(:flash_errors?).should be_true
        assigns(:flash_array).first[:message].should include("Name has already been taken")
      end

      it "#does not allow duplicate names when editing" do
        @params[:id] = @schedule.id
        @params[:name] = "schedule01"
        controller.instance_variable_set(:@_params, @params)
        FactoryGirl.create(:miq_schedule, :name => @params[:name], :userid => "test", :towhat => "Vm")
        controller.send(:schedule_edit)
        controller.send(:flash_errors?).should be_true
        assigns(:flash_array).first[:message].should include("Name has already been taken")
      end
    end
  end

  context "replace_right_cell" do
    before do
      MiqRegion.seed
      zone       = FactoryGirl.create(:zone)
      MiqRegion.my_region.stub(:zones).and_return([zone])
      miq_server = FactoryGirl.create(:miq_server, :guid => 'guid', :zone => zone)
      MiqServer.stub(:my_server).and_return(miq_server)
    end

    it "it renders replace_right_cell" do
      controller.instance_variable_set(:@sb,
                                       :trees         => {:settings_tree => {:open_nodes => []}},
                                       :active_accord => 'active_accord',
                                       :active_tab    => 'settings_server',
                                       :active_tree   => :settings_tree)
      controller.should_receive(:x_active_tree_replace_cell)
      controller.should_receive(:replace_explorer_trees)
      controller.should_receive(:rebuild_toolbars)
      controller.should_receive(:handle_bottom_cell)
      controller.should_receive(:extra_js_commands)
      controller.should_receive(:render)
      controller.send(:replace_right_cell, 'svr', [:settings])
      expect(response.status).to eq(200)
    end
  end
end

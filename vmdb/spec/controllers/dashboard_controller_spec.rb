require "spec_helper"

describe DashboardController do
  before(:each) do
    described_class.any_instance.stub(:set_user_time_zone)
  end

  context "POST authenticate" do
    it "validates user" do
      role = FactoryGirl.create(:miq_user_role, :name => 'test_role')
      group = FactoryGirl.create(:miq_group, :description => 'test_group', :miq_user_role => role)
      user = FactoryGirl.create(:user, :userid => 'wilma', :miq_groups => [group])
      User.stub(:authenticate).and_return(user)
      controller.stub(:get_vmdb_config).and_return({:product => {}})
      UserValidationService.any_instance.stub(:user_is_super_admin?).and_return(true)
      controller.stub(:start_url_for_user).and_return('some_url')
      post :authenticate, :user_name => user.userid, :user_password => 'secret'
      session[:userid].should == user.userid
    end
  end

  context "#validate_user" do
    let(:server) { active_record_instance_double("MiqServer", :logon_status => :ready) }

    before do
      MiqServer.stub(:my_server).with(true).and_return(server)
    end

    it "returns flash message when user's group is missing" do
      user = FactoryGirl.create(:user, :userid => 'wilma')
      User.stub(:authenticate).and_return(user)
      validation = controller.send(:validate_user, user)
      expect(validation.flash_msg).to include('User\'s Group is missing')
    end

    it "returns flash message when user's role is missing" do
      group = FactoryGirl.create(:miq_group, :description => 'test_group')
      user = FactoryGirl.create(:user, :userid => 'wilma', :miq_groups => [group])
      User.stub(:authenticate).and_return(user)
      validation = controller.send(:validate_user, user)
      expect(validation.flash_msg).to include('User\'s Role is missing')
    end

    it "returns url for the user and sets user's group/role id in session" do
      role = FactoryGirl.create(:miq_user_role, :name => 'test_role')
      group = FactoryGirl.create(:miq_group, :description => 'test_group', :miq_user_role => role)
      user = FactoryGirl.create(:user, :userid => 'wilma', :miq_groups => [group])
      User.stub(:authenticate).and_return(user)
      controller.stub(:get_vmdb_config).and_return({:product => {}})
      controller.stub(:start_url_for_user).and_return('some_url')
      UserValidationService.any_instance.stub(:user_is_super_admin?).and_return(true)
      validation = controller.send(:validate_user, user)
      session[:group].should eq(group.id)
      session[:role].should eq(role.id)
      expect(validation.flash_msg).to be_nil
      expect(validation.url).to eq('some_url')
    end
  end

  context "Create Dashboard" do
    it "dashboard show" do
      #create dashboard for a group
      ws = FactoryGirl.create(:miq_widget_set, :name => "default",
                              :set_data => {:last_group_db_updated => Time.now.utc,
                              :col1 => [1], :col2 => [], :col3 =>[]})

      ur = FactoryGirl.create(:miq_user_role)
      group = FactoryGirl.create(:miq_group, :miq_user_role => ur, :settings => {:dashboard_order => [ws.id]})
      user = FactoryGirl.create(:user, :userid => 'wilma', :miq_groups => [group])

      controller.instance_variable_set(:@sb, {:active_db => ws.name})
      controller.instance_variable_set(:@tabs, [])
      controller.instance_variable_set(:@temp, {})
      controller.stub(:role_allows)
      session[:group] = user.current_group.id
      session[:userid] = user.userid
      #create a user's dashboard using group dashboard name.
      user_ws = FactoryGirl.create(:miq_widget_set, :name => "#{session[:userid]}|#{session[:group]}|#{ws.name}",
                                   :set_data => {:last_group_db_updated => Time.now.utc,
                                                 :col1 => [1], :col2 => [], :col3 =>[]})
      controller.show
      controller.send(:flash_errors?).should_not be_true
    end
  end

  context "#main_tab redirects to correct url when maintab is pressed by limited access user" do
    before do
      MiqRegion.seed

      described_class.any_instance.stub(:set_user_time_zone)
      controller.stub(:check_privileges).and_return(true)
    end

    main_tabs = {
                  :clo => "vm_cloud_explorer",
                  :inf => "vm_infra_explorer",
                  :svc => "vm_explorer_accords"
                }
    main_tabs.each do |tab, feature|
      it "for tab ':#{tab}'" do
        seed_specific_product_features(feature)
        session[:tab_url] = {}
        post :maintab, :tab => tab
        url_controller = Menu::Manager.tab_features_by_id(tab).find { |f| f.ends_with?("_explorer") }
        response.body.should include("#{DashboardController::EXPLORER_FEATURE_LINKS[url_controller]}/explorer")
      end
    end
  end

  context "#start_url_for_user" do
    before do
      MiqRegion.seed
      MiqShortcut.seed
      described_class.any_instance.stub(:set_user_time_zone)
      controller.stub(:check_privileges).and_return(true)
    end

    it "retuns start page url that user has set as startpage in settings" do
      settings = {:display => {:startpage => "/dashboard/show"}}
      seed_all_product_features(settings)
      url = controller.send(:start_url_for_user, nil)
      url.should eq("/dashboard/show")
    end

    it "returns first url that user has access to as start page when user doesn't have access to startpage set in settings" do
      settings = {:display => {:startpage => "/dashboard/show"}}
      seed_specific_product_features_with_user_settings("vm_cloud_explorer", settings)
      url = controller.send(:start_url_for_user, nil)
      url.should eq("/vm_cloud/explorer?accordion=instances")
    end
  end

  context "#get_layout" do
    it "sets layout same as session[:layout] when changing window size" do
      request.parameters["action"] = "window_sizes"
      session[:layout] = "host"
      layout = controller.send(:get_layout)
      layout.should eq(session[:layout])
    end

    it "defaults layout to login on Login screen" do
      layout = controller.send(:get_layout)
      layout.should eq("login")
    end
  end
end

require "spec_helper"

describe DashboardController do
  before(:each) do
    described_class.any_instance.stub(:set_user_time_zone)
  end

  context "POST authenticate" do
    it "validates user" do
      user = FactoryGirl.create(:user, :userid => 'wilma')
      User.stub(:authenticate).and_return(user)
      post :authenticate, :user_name => user.userid, :user_password => 'secret'
      session[:userid].should == user.userid
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
                  :svc => "vm_explorer"
                }
    main_tabs.each do |tab, feature|
      it "for tab ':#{tab}'" do
        seed_specific_product_features(feature)
        session[:tab_url] = Hash.new
        post :maintab, :tab => tab
        tab_features = MAIN_TAB_FEATURES.collect{|f| f.last if f.first == MAIN_TABS[tab]}.compact.first
        url_controller = tab_features.find{|f|f.ends_with?("_accords")}
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
end

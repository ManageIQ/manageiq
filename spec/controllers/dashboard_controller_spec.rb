require "spec_helper"

describe DashboardController do
  context "POST authenticate" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
    end

    let(:user_with_role) do
      FactoryGirl.create(:user, :role => "random")
    end

    it "validates user" do
      skip_data_checks
      post :authenticate, :user_name => user_with_role.userid, :user_password => 'dummy'
      expect_successful_login(user_with_role)
    end

    it "fails validation" do
      skip_data_checks
      post :authenticate
      expect_failed_login('Name is required')
    end

    it "requires user" do
      skip_data_checks
      post :authenticate, :user_name => 'bogus', :password => "bad"
      expect_failed_login('username or password')
    end

    it "requires group" do
      user = FactoryGirl.create(:user, :current_group => nil)
      post :authenticate, :user_name => user.userid, :user_password => "dummy"
      expect_failed_login('Group')
    end

    it "requires role" do
      user = FactoryGirl.create(:user_with_group)
      post :authenticate, :user_name => user.userid, :user_password => "dummy"
      expect_failed_login('Role')
    end

    it "allow users in with no vms" do
      skip_data_checks
      post :authenticate, :user_name => user_with_role.userid, :user_password => "dummy"
      expect_successful_login(user_with_role)
    end

    it "redirects to a proper start page" do
      skip_data_checks('some_url')
      post :authenticate, :user_name => user_with_role.userid, :user_password => "dummy"
      expect_successful_login(user_with_role, 'some_url')
    end
  end

  # would like to test these controller by calling authenticate
  # need to ensure all cases are handled before deleting these
  context "#validate_user" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
    end

    it "returns flash message when user's group is missing" do
      user = FactoryGirl.create(:user)
      User.stub(:authenticate).and_return(user)
      validation = controller.send(:validate_user, user)
      expect(validation.flash_msg).to include('User\'s Group is missing')
    end

    it "returns flash message when user's role is missing" do
      user = FactoryGirl.create(:user_with_group)
      User.stub(:authenticate).and_return(user)
      validation = controller.send(:validate_user, user)
      expect(validation.flash_msg).to include('User\'s Role is missing')
    end

    it "returns url for the user and sets user's group/role id in session" do
      user = FactoryGirl.create(:user, :role => "test")
      User.stub(:authenticate).and_return(user)
      controller.stub(:get_vmdb_config).and_return({:product => {}})
      skip_data_checks('some_url')
      validation = controller.send(:validate_user, user)
      expect(controller.current_groupid).to eq(user.current_group_id)
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
      user = FactoryGirl.create(:user, :miq_groups => [group])

      controller.instance_variable_set(:@sb, {:active_db => ws.name})
      controller.instance_variable_set(:@tabs, [])
      login_as user
      #create a user's dashboard using group dashboard name.
      FactoryGirl.create(:miq_widget_set,
                         :name     => "#{user.userid}|#{group.id}|#{ws.name}",
                         :set_data => {:last_group_db_updated => Time.now.utc, :col1 => [1], :col2 => [], :col3 => []})
      controller.show
      controller.send(:flash_errors?).should_not be_true
    end
  end

  context "#main_tab redirects to correct url when maintab is pressed by limited access user" do
    before do
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
        login_as FactoryGirl.create(:user, :features => feature)
        session[:tab_url] = {}
        post :maintab, :tab => tab
        url_controller = Menu::Manager.tab_features_by_id(tab).find { |f| f.ends_with?("_explorer") }
        response.body.should include("#{DashboardController::EXPLORER_FEATURE_LINKS[url_controller]}/explorer")
      end
    end
  end

  context "#start_url_for_user" do
    before do
      MiqShortcut.seed
      controller.stub(:check_privileges).and_return(true)
    end

    it "retuns start page url that user has set as startpage in settings" do
      login_as FactoryGirl.create(:user, :features => "everything")
      controller.instance_variable_set(:@settings, :display => {:startpage => "/dashboard/show"})

      controller.stub(:role_allows).and_return(true)
      url = controller.send(:start_url_for_user, nil)
      url.should eq("/dashboard/show")
    end

    it "returns first url that user has access to as start page when user doesn't have access to startpage set in settings" do
      login_as FactoryGirl.create(:user, :features => "vm_cloud_explorer")
      controller.instance_variable_set(:@settings, :display => {:startpage => "/dashboard/show"})
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

  def skip_data_checks(url = '/')
    UserValidationService.any_instance.stub(:server_ready?).and_return(true)
    controller.stub(:start_url_for_user).and_return(url)
  end

  # logs in and redirects to home url
  def expect_successful_login(user, target_url = nil)
    expect(controller.send(:current_user)).to eq(user)
    expect(response.body).to match(/location.href.*#{target_url}/)
  end

  def expect_failed_login(flash = nil)
    expect(controller.send(:current_user)).to be_nil
    expect(response.body).not_to match(/location.href/)

    # TODO: figure out why flash messages are not in result.body
    expect(response.body).to match(/flash_msg_div/) if flash
    # expect(result.body.to match(/flash_msg_div.*replaceWith.*#{msg}/) if flash
  end
end

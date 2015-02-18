require "spec_helper"

describe OpsController do
  before(:each) do
    set_user_privileges
  end

  describe 'x_button' do
    describe 'corresponding methods are called for allowed actions' do
      OpsController::OPS_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
        it "calls the appropriate method: '#{method}' for action '#{action_name}'" do
          controller.should_receive(method)
          get :x_button, :pressed => action_name
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :pressed => 'random_dude', :format => :html
      expect { response }.to render_template('layouts/exception')
    end
  end

  it 'can view the db_settings tab' do
    EvmSpecHelper.create_guid_miq_server_zone
    session[:sandboxes] = {"ops" => {:active_tree => :vmdb_tree,
                                     :active_tab  => 'db_settings',
                                     :trees       => {:vmdb_tree => {:active_node => 'root'}}}}
    session[:settings] = {:views => {}, :perpage => {:list => 10}}
    post :change_tab, :tab_id => 'db_settings', :format => :json
  end

  it 'can view the db_connections tab' do
    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone
    session[:sandboxes] = {"ops" => {:active_tree => :vmdb_tree,
                                     :active_tab  => 'db_connections',
                                     :trees       => {:vmdb_tree => {:active_node => 'root'}}}}
    session[:settings] = {:views => {}, :perpage => {:list => 10}}
    post :change_tab, :tab_id => 'db_connections', :format => :json
    expect(response.status).to eq(200)
  end

  #  def rbac_user_edit
  #
  # def rbac_user_set_record_vars(user)
  describe 'rbac_user_edit' do
    it 'can add a user w/ group' do
      session[:settings] = {:views => {}, :perpage => {:list => 10}}
      session[:edit] = {
        :key => 'rbac_user_edit__new',
        :current => {},
        :new => {
          :name      => 'test7',
          :userid    => 'test7',
          :email     => 'test7@foo.bar',
          :group     => 'test_group',
          :password  => 'test7',
          :password2 => 'test7',
        }
      }

      controller.should_receive(:replace_right_cell)
      get :rbac_user_edit, :button => 'add'
    end

    it 'cannot add a user w/o matching passwords' do
      session[:settings] = {}
      session[:settings] = {:views => {}, :perpage => {:list => 10}}
      session[:edit] = {
        :key => 'rbac_user_edit__new',
        :new => {
          :name      => 'test7',
          :userid    => 'test7',
          :email     => 'test7@foo.bar',
          :group     => 'test_group',
          :password  => 'test7',
          :password2 => 'test8',
        }
      }

      controller.should_receive(:render_flash)
      get :rbac_user_edit, :button => 'add'
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should == "Password/Verify Password do not match"
      flash_messages.first[:level].should == :error
    end

    it 'cannot add a user w/o group' do
      session[:settings] = {}
      session[:settings] = {:views => {}, :perpage => {:list => 10}}
      session[:edit] = {
        :key => 'rbac_user_edit__new',
        :new => {
          :name      => 'test7',
          :userid    => 'test7',
          :email     => 'test7@foo.bar',
          :group     => nil,
          :password  => 'test7',
          :password2 => 'test7',
        }
      }

      controller.should_receive(:render_flash)
      get :rbac_user_edit, :button => 'add'
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should == "A User must be assigned to a Group"
      flash_messages.first[:level].should == :error
    end
  end
end

describe PxeController do
  before(:each) do
    stub_user(:features => :all)
  end

  describe '#tree_select ' do
    it 'calls methods with x_node as param' do
      controller.instance_variable_set(:@_params, :id => 'root', :tree => :pxe_servers_tree)
      expect(controller).to receive(:get_node_info).with("root")
      expect(controller).to receive(:replace_right_cell).with(:nodetype => "root")
      controller.tree_select
    end
  end

  describe '#accordion_select ' do
    it 'calls methods with x_node as param' do
      controller.instance_variable_set(:@_params, :id => 'pxe_servers_accord', :tree => :pxe_servers_tree)
      allow(controller).to receive(:x_node).and_return('root')
      expect(controller).to receive(:get_node_info).with("root")
      expect(controller).to receive(:replace_right_cell).with(:nodetype => "root")
      controller.accordion_select
    end
  end

  describe 'x_button' do
    before do
      ApplicationController.handle_exceptions = true
    end

    describe 'corresponding methods are called for allowed actions' do
      PxeController::PXE_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
        it "calls the appropriate method: '#{method}' for action '#{action_name}'" do
          expect(controller).to receive(method)
          get :x_button, :params => { :pressed => action_name }
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :params => { :pressed => 'random_dude', :format => :html }
      expect(response).to render_template('layouts/exception')
    end

    it "Pressing Refresh button should show display name in the flash message" do
      pxe = FactoryGirl.create(:pxe_server)
      allow(MiqServer).to receive(:my_zone).and_return("default")
      controller.instance_variable_set(:@_params, :id => pxe.id)
      controller.instance_variable_set(:@sb,
                                       :trees       => {
                                         :pxe_tree => {:active_node => "ps-#{pxe.id}"}
                                       },
                                       :active_tree => :pxe_tree
                                      )
      allow(controller).to receive(:get_node_info)
      allow(controller).to receive(:replace_right_cell)
      controller.send(:pxe_server_refresh)
      expect(assigns(:flash_array).first[:message]).to include("Refresh Relationships successfully initiated")
    end
  end

  context "#restore_password" do
    it "populates the password from the pxe record if params[:restore_password] exists" do
      ps = PxeServer.create
      allow(ps).to receive(:authentication_password).with(:default).and_return("default_password")
      edit = {:pxe_id => ps.id, :new => {}}
      controller.instance_variable_set(:@edit, edit)
      controller.instance_variable_set(:@ps, ps)
      controller.instance_variable_set(:@_params,
                                       :restore_password => "true",
                                       :log_password     => "[FILTERED]",
                                       :log_verify       => "[FILTERED]")
      controller.send(:restore_password)
      expect(assigns(:edit)[:new][:log_password]).to eq(ps.authentication_password(:default))
    end
  end
end

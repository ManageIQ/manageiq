require "spec_helper"

describe CatalogController do
  before(:each) do
    set_user_privileges
  end

  # some methods should not be accessible through the legacy routes
  # either by being private or through the hide_action mechanism
  it 'should not allow call of hidden/private actions' do
    expect {
      post :process_sts
    }.to raise_error AbstractController::ActionNotFound
  end

  describe 'x_button' do
    describe 'corresponding methods are called for allowed actions' do
      CatalogController::CATALOG_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, actual_method|
        it "calls the appropriate method: '#{actual_method}' for action '#{action_name}'" do
          controller.should_receive(actual_method)
          get :x_button, :pressed => action_name
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :pressed => 'random_dude', :format => :html
      expect { response }.to render_template('layouts/exception')
    end
  end

  context "#atomic_st_edit" do
    it "Atomic Service Template and it's Resource Actions are saved" do
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@_params, {:button => "save"})
      st = FactoryGirl.create(:service_template)
      retire_fqname = "ns/cls/inst"
      provision_fqname = "ns1/cls1/inst1"
      recon_fqname = "ns2/cls2/inst2"
      edit = {
        :new          => {
          :name               => "New Name",
          :description        => "New Description",
          :reconfigure_fqname => recon_fqname,
          :retire_fqname      => retire_fqname,
          :fqname             => provision_fqname},
        :key          => "prov_edit__new",
        :rec_id       => st.id,
        :st_prov_type => "generic"
      }
      controller.instance_variable_set(:@edit, edit)
      session[:edit] = edit
      controller.stub(:replace_right_cell)
      controller.send(:atomic_st_edit)
      {'Provision' => provision_fqname, 'Reconfigure' => recon_fqname, 'Retirement' => retire_fqname}.each do |k, v|
        st.resource_actions.find_by_action(k).fqname.should == "/#{v}"
      end
    end
  end

  context "#st_edit" do
    it "@record is cleared out after Service Template is added" do
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@_params, {:button => "add"})
      st = FactoryGirl.create(:service_template)
      controller.instance_variable_set(:@record, st)
      edit = {
          :new => {:name => "New Name", :description => "New Description", :selected_resources => [st.id], :rsc_groups => [[{:name => "Some name"}]]},
          :key => "st_edit__new",
          :rec_id => st.id,
      }
      controller.instance_variable_set(:@edit, edit)
      session[:edit] = edit
      controller.stub(:replace_right_cell)
      controller.send(:st_edit)
      assigns(:record).should == nil
    end
  end
end

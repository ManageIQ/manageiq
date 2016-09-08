describe "catalog/_form.html.haml" do
  include Spec::Support::AutomationHelper

  before do
    set_controller_for_view("catalog")
    set_controller_for_view_to_be_nonrestful
    @edit = {:new => {:available_catalogs => [], :available_dialogs => {}}}
    @sb = {:st_form_active_tab => "Basic", :trees => {:ot_tree => {:open_nodes => []}}, :active_tree => :ot_tree}
    user = FactoryGirl.create(:user_with_group)
    login_as user
    create_state_ae_model(:name => 'LUIGI', :ae_class => 'CLASS1', :ae_namespace => 'A/B/C')
    create_ae_model(:name => 'MARIO', :ae_class => 'CLASS3', :ae_namespace => 'C/D/E')
    @automate_tree = TreeBuilderAeClass.new(:automate_tree, "automate", @sb)
  end

  it "Renders form when adding catalog bundle and st_prov_type is not set" do
    render
    expect(response).to render_template(:partial => "catalog/_form_basic_info")
  end
end

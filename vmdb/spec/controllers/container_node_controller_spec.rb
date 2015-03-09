require "spec_helper"

describe ContainerNodeController do
  render_views
  before(:each) do
    set_user_privileges
  end

  it "renders index" do
    get :index
    expect(response.status).to eq(302)
    response.should redirect_to(:action => 'show_list')
  end

  it "renders show screen" do
    ems = FactoryGirl.create(:ext_management_system)
    container_node = ContainerNode.create(:ext_management_system => ems)
    get :show, :id => container_node.id
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end
end

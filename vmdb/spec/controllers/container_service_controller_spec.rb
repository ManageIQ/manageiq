require "spec_helper"

describe ContainerServiceController do
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
    container_service = ContainerService.create(:ext_management_system => ems, :name => "Test Service")
    get :show, :id => container_service.id
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
    expect(assigns(:breadcrumbs)).to eq([{:name=>"Test Service (Summary)", :url=>"/container_service/show/#{container_service.id}"}])
  end

  it "renders show_list" do
    get :show_list
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end
end

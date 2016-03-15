describe EmsContainerController do
  before(:each) do
    set_user_privileges
  end

  it "#new" do
    controller.instance_variable_set(:@breadcrumbs, [])
    get :new

    expect(response.status).to eq(200)
    expect(allow(controller).to receive(:edit)).to_not be_nil
  end

  it "#show" do
    ems = FactoryGirl.create(:ems_kubernetes)
    get :show, :params => { :id => ems.id }

    expect(response.status).to eq(200)
    expect(response).to render_template('ems_container/show')
  end
end

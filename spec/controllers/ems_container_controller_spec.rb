require "spec_helper"

describe EmsContainerController do
  before(:each) do
    set_user_privileges
  end

  it "#new" do
    controller.instance_variable_set(:@breadcrumbs, [])
    get :new

    expect(response.status).to eq(200)
    expect(controller.stub(:edit)).to_not be_nil
  end


  end
end

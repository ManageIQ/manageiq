require "spec_helper"

describe VmInfraController do
  before(:each) do
    set_user_privileges
  end

  render_views

  it 'can render the explorer' do
    session[:settings] = {:views => {}, :perpage => {:list => 10}}
    session[:userid] = User.current_user.userid
    session[:eligible_groups] = []

    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone
    expect(MiqServer.my_server).to be
    get :explorer
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end
end

require "spec_helper"

describe VmdbwsController do
  # NOTE: VmdbwsInvetorySpec relies upon @username and authenticate returning true
  #       change those tests too

  it "handles security turned off" do
    expect(controller).to receive(:get_vmdb_config).and_return(:webservices => {:integrate => {:security => "none"}})
    expect(controller).not_to receive(:authenticate_or_request_with_http_basic)
    expect(controller.send(:authenticate)).to eq(true)
    expect(assigns(:username)).to eq(VmdbwsSupport::SYSTEM_USER)
  end

  it "handles region to region password" do
    expect(controller).to receive(:get_vmdb_config).and_return(:webservices => {:integrate => {:security => "basic"}})
    http_login VmdbwsSupport::SYSTEM_USER, VmdbwsSupport.system_password

    expect(User).not_to receive(:authenticate_with_http_basic)
    expect(controller.send(:authenticate)).to eq(true)
    expect(assigns(:username)).to eq(VmdbwsSupport::SYSTEM_USER)
  end

  it "handles bad region to region passwords" do
    expect(controller).to receive(:get_vmdb_config).twice
      .and_return(:webservices => {:integrate => {:security => "basic"}})
    http_login VmdbwsSupport::SYSTEM_USER, "bad"

    expect(User).not_to receive(:authenticate_with_http_basic)
    expect { controller.send(:authenticate) }.to raise_error
  end

  it "handles username password" do
    user = FactoryGirl.create(:user, :password => "dummy")
    http_login user.userid, user.password

    expect(controller).to receive(:get_vmdb_config).twice
      .and_return(:webservices => {:integrate => {:security => "basic"}, :authentication_timeout => "30.seconds"})
    expect(controller.send(:authenticate)).to eq(true)
    expect(assigns(:username)).to eq(user.userid)
  end

  it "handles bad username password" do
    http_login "joe", "password"

    expect(controller).to receive(:get_vmdb_config).twice
      .and_return(:webservices => {:integrate => {:security => "basic"}, :authentication_timeout => "30.seconds"})

    expect { controller.send(:authenticate) }.to raise_error
    expect(assigns(:username)).to eq("joe")
  end
end

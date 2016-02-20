describe StorageManagerController do
  render_views
  before(:each) do
    @zone = EvmSpecHelper.local_miq_server.zone
    set_user_privileges
  end

  it "renders index" do
    get :index
    expect(response.status).to eq(302)
    expect(response).to redirect_to(:action => 'show_list')
  end

  it "renders a new page" do
    set_view_10_per_page
    post :new, :format => :js
    expect(response.status).to eq(200)
  end

  context "@edit password fields" do
    it "sets @edit password fields to blank when change password is clicked" do
      sm = StorageManager.create(:name => "foo")
      auth = Authentication.create(:userid        => "userid",
                                   :password      => "password",
                                   :resource_id   => sm.id,
                                   :resource_type => "StorageManager")
      post :edit, :params => { :id => sm.id }
      post :form_field_changed, :params => { :id => sm.id, :password => "", :verify => "" }
      expect(response.status).to eq(200)
      edit = controller.instance_variable_get(:@edit)
      expect(edit[:new][:userid]).to eq(auth.userid)
      expect(edit[:new][:password]).to eq("")
    end

    it "sets @edit password fields to the stored password value when cancel password is clicked" do
      sm = StorageManager.create(:name => "foo")
      auth = Authentication.create(:userid        => "userid",
                                   :password      => "password",
                                   :resource_id   => sm.id,
                                   :resource_type => "StorageManager")
      post :edit, :params => { :id => sm.id }
      post :form_field_changed, :params => { :id => sm.id, :password => "", :verify => "", :restore_password => true }
      expect(response.status).to eq(200)
      edit = controller.instance_variable_get(:@edit)
      expect(edit[:new][:userid]).to eq(auth.userid)
      expect(edit[:new][:password]).to eq(auth.password)
    end
  end

  context "Validate" do
    let(:mocked_sm) { double(StorageManager) }

    it "uses @edit password value for validation" do
      Zone.create(:name => "default", :description => "default")
      edit = {:new => {:name      => "Storage Manager",
                       :hostname  => "test",
                       :ipaddress => "10.10.10.10",
                       :port      => "1110",
                       :zone      => "default",
                       :userid    => "username",
                       :password  => "password"}}

      controller.instance_variable_set(:@edit, edit)
      expect(mocked_sm).to receive(:name=).with(edit[:new][:name])
      expect(mocked_sm).to receive(:hostname=).with(edit[:new][:hostname])
      expect(mocked_sm).to receive(:ipaddress=).with(edit[:new][:ipaddress])
      expect(mocked_sm).to receive(:port=).with(edit[:new][:port])
      expect(mocked_sm).to receive(:zone=).with(Zone.find_by_name(edit[:new][:zone]))
      expect(mocked_sm).to receive(:update_authentication)
        .with({:default => {:userid => "username", :password => "password"}},
              :save => true)
      controller.send(:set_record_vars, mocked_sm)
    end
  end

  def set_view_10_per_page
    session[:settings] = {:default_search => 'foo',
                          :views          => {:storage_manager => 'list'},
                          :perpage        => {:list => 10}}
  end
end

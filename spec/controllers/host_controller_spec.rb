describe HostController do
  context "#button" do
    render_views

    before(:each) do
      set_user_privileges
      EvmSpecHelper.create_guid_miq_server_zone

      ApplicationController.handle_exceptions = true
    end

    it "doesn't break" do
      h1 = FactoryGirl.create(:host)
      h2 = FactoryGirl.create(:host)
      session[:host_items] = [h1.id, h2.id]
      session[:settings] = {:views     => {:host => 'grid'},
                            :display   => {:quad_truncate => 'f'},
                            :quadicons => {:host => 'foo'}}
      get :edit
      expect(response.status).to eq(200)
    end

    it "when VM Right Size Recommendations is pressed" do
      expect(controller).to receive(:vm_right_size)
      post :button, :params => { :pressed => 'vm_right_size', :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Migrate is pressed" do
      expect(controller).to receive(:prov_redirect).with("migrate")
      post :button, :params => { :pressed => 'vm_migrate', :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Retire is pressed" do
      expect(controller).to receive(:retirevms).once
      post :button, :params => { :pressed => 'vm_retire', :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Manage Policies is pressed" do
      expect(controller).to receive(:assign_policies).with(VmOrTemplate)
      post :button, :params => { :pressed => 'vm_protect', :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when MiqTemplate Manage Policies is pressed" do
      expect(controller).to receive(:assign_policies).with(VmOrTemplate)
      post :button, :params => { :pressed => 'miq_template_protect', :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Tag is pressed" do
      expect(controller).to receive(:tag).with(VmOrTemplate)
      post :button, :params => { :pressed => 'vm_tag', :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when MiqTemplate Tag is pressed" do
      expect(controller).to receive(:tag).with(VmOrTemplate)
      post :button, :params => { :pressed => 'miq_template_tag', :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when Custom Button is pressed" do
      host = FactoryGirl.create(:host)
      custom_button = FactoryGirl.create(:custom_button, :applies_to_class => "Host")
      d = FactoryGirl.create(:dialog, :label => "Some Label")
      dt = FactoryGirl.create(:dialog_tab, :label => "Some Tab", :order => 0)
      d.dialog_tabs << dt
      ra = FactoryGirl.create(:resource_action, :dialog_id => d.id)
      custom_button.resource_action = ra
      custom_button.save
      post :button, :params => { :pressed => "custom_button", :id => host.id, :button_id => custom_button.id }
      expect(response.status).to eq(200)
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when Drift button is pressed" do
      expect(controller).to receive(:drift_analysis)
      post :button, :params => { :pressed => 'common_drift', :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end
  end

  context "#create" do
    it "can create a host with custom id and no host name" do
      set_user_privileges
      controller.instance_variable_set(:@breadcrumbs, [])

      controller.instance_variable_set(:@_params,
                                       :button   => "add",
                                       :id       => "new",
                                       :name     => 'foobar',
                                       :hostname => nil,
                                       :custom_1 => 'bar'
                                      )

      expect_any_instance_of(Host).to receive(:save).and_call_original
      expect(controller).to receive(:render)
      controller.send(:create)
      expect(response.status).to eq(200)
    end

    it "doesn't crash when trying to validate a new host" do
      set_user_privileges
      controller.instance_variable_set(:@breadcrumbs, [])
      controller.new

      controller.instance_variable_set(:@_params,
                                       :button           => "validate",
                                       :type             => "default",
                                       :id               => "new",
                                       :name             => 'foobar',
                                       :hostname         => '127.0.0.1',
                                       :default_userid   => "abc",
                                       :default_password => "def",
                                       :default_verify   => "def",
                                       :user_assigned_os => "linux_generic"
                                      )
      expect(controller).to receive(:render)
      controller.send(:create)
      expect(response.status).to eq(200)
    end
  end

  context "#set_record_vars" do
    it "strips leading/trailing whitespace from hostname/ipaddress when adding infra host" do
      set_user_privileges
      controller.instance_variable_set(:@_params,
                                       :name     => 'EMS 2',
                                       :emstype  => 'rhevm',
                                       :hostname => '  10.10.10.10  '
                                      )
      host = Host.new
      controller.send(:set_record_vars, host, false)
      expect(host.hostname).to eq('10.10.10.10')
    end
  end

  context "#show_association" do
    before(:each) do
      set_user_privileges
      @host = FactoryGirl.create(:host)
      @guest_application = FactoryGirl.create(:guest_application, :name => "foo", :host_id => @host.id)
    end

    it "renders show_details" do
      controller.instance_variable_set(:@breadcrumbs, [])
      allow(controller).to receive(:get_view)
      get :guest_applications, :params => { :id => @host.id }
      expect(response.status).to eq(200)
      expect(response).to render_template('host/show')
      expect(assigns(:breadcrumbs)).to eq([{:name => "#{@host.name} (Packages)",
                                            :url  => "/host/guest_applications/#{@host.id}"}])
      expect(assigns(:devices)).to be_kind_of(Array)
    end
  end

  it "#show" do
    set_user_privileges
    host = FactoryGirl.create(:host,
                              :hardware => FactoryGirl.create(:hardware,
                                                              :cpu_sockets          => 2,
                                                              :cpu_cores_per_socket => 4,
                                                              :cpu_total_cores      => 8
                                                             )
                             )

    get :show, :params => { :id => host.id }

    expect(response.status).to eq(200)
    expect(response).to render_template('host/show')
  end

  context "#set_credentials" do
    let(:mocked_host) { double(Host) }
    it "uses params[:default_password] for validation if one exists" do
      controller.instance_variable_set(:@_params,
                                       :default_userid   => "default_userid",
                                       :default_password => "default_password2")
      creds = {:userid => "default_userid", :password => "default_password2"}
      expect(mocked_host).to receive(:update_authentication).with({:default => creds}, {:save => false})
      expect(controller.send(:set_credentials, mocked_host, :validate)).to include(:default => creds)
    end

    it "uses the stored password for validation if params[:default_password] does not exist" do
      controller.instance_variable_set(:@_params, :default_userid => "default_userid")
      expect(mocked_host).to receive(:authentication_password).and_return('default_password')
      creds = {:userid => "default_userid", :password => "default_password"}
      expect(mocked_host).to receive(:update_authentication).with({:default => creds}, {:save => false})
      expect(controller.send(:set_credentials, mocked_host, :validate)).to include(:default => creds)
    end

    it "uses the passwords from param for validation if they exist" do
      controller.instance_variable_set(:@_params,
                                       :default_userid   => "default_userid",
                                       :default_password => "default_password2",
                                       :remote_userid    => "remote_userid",
                                       :remote_password  => "remote_password2")
      default_creds = {:userid => "default_userid", :password => "default_password2"}
      remote_creds = {:userid => "remote_userid", :password => "remote_password2"}
      expect(mocked_host).to receive(:update_authentication).with({:default => default_creds,
                                                                   :remote  => remote_creds}, :save => false)

      expect(controller.send(:set_credentials, mocked_host, :validate)).to include(:default => default_creds,
                                                                                   :remote  => remote_creds)
    end

    it "uses the stored passwords for validation if passwords dont exist in params" do
      controller.instance_variable_set(:@_params,
                                       :default_userid => "default_userid",
                                       :remote_userid  => "remote_userid",)
      expect(mocked_host).to receive(:authentication_password).and_return('default_password')
      expect(mocked_host).to receive(:authentication_password).with(:remote).and_return('remote_password')
      default_creds = {:userid => "default_userid", :password => "default_password"}
      remote_creds = {:userid => "remote_userid", :password => "remote_password"}
      expect(mocked_host).to receive(:update_authentication).with({:default => default_creds,
                                                               :remote  => remote_creds}, :save => false)

      expect(controller.send(:set_credentials, mocked_host, :validate)).to include(:default => default_creds,
                                                                                   :remote  => remote_creds)
    end

    it "uses the stored passwords/passwords from params to do validation" do
      controller.instance_variable_set(:@_params,
                                       :default_userid   => "default_userid",
                                       :default_password => "default_password2",
                                       :ws_userid        => "ws_userid",
                                       :ipmi_userid      => "ipmi_userid")
      expect(mocked_host).to receive(:authentication_password).with(:ws).and_return('ws_password')
      expect(mocked_host).to receive(:authentication_password).with(:ipmi).and_return('ipmi_password')
      default_creds = {:userid => "default_userid", :password => "default_password2"}
      ws_creds = {:userid => "ws_userid", :password => "ws_password"}
      ipmi_creds = {:userid => "ipmi_userid", :password => "ipmi_password"}
      expect(mocked_host).to receive(:update_authentication).with({:default => default_creds,
                                                               :ws      => ws_creds,
                                                               :ipmi    => ipmi_creds}, :save => false)

      expect(controller.send(:set_credentials, mocked_host, :validate)).to include(:default => default_creds,
                                                                                   :ws      => ws_creds,
                                                                                   :ipmi    => ipmi_creds)
    end
  end

  context "#render pages" do
    render_views
    before do
      set_user_privileges
      EvmSpecHelper.create_guid_miq_server_zone
    end
    it "renders a new page with ng-required condition set to false for password" do
      get :new
      expect(response.status).to eq(200)
      expect(response.body).to include("name='default_password' ng-disabled='!showVerify(&#39;default_userid&#39;)' ng-model='hostModel.default_password' ng-required='false'")
    end
  end
end

require "spec_helper"

describe HostController do
  context "#button" do
    render_views

    before(:each) do
      set_user_privileges
      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.create_guid_miq_server_zone
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
      controller.should_receive(:vm_right_size)
      post :button, :pressed => 'vm_right_size', :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Migrate is pressed" do
      controller.should_receive(:prov_redirect).with("migrate")
      post :button, :pressed => 'vm_migrate', :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Retire is pressed" do
      controller.should_receive(:retirevms).once
      post :button, :pressed => 'vm_retire', :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Manage Policies is pressed" do
      controller.should_receive(:assign_policies).with(VmOrTemplate)
      post :button, :pressed => 'vm_protect', :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when MiqTemplate Manage Policies is pressed" do
      controller.should_receive(:assign_policies).with(VmOrTemplate)
      post :button, :pressed => 'miq_template_protect', :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Tag is pressed" do
      controller.should_receive(:tag).with(VmOrTemplate)
      post :button, :pressed => 'vm_tag', :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when MiqTemplate Tag is pressed" do
      controller.should_receive(:tag).with(VmOrTemplate)
      post :button, :pressed => 'miq_template_tag', :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when Custom Button is pressed" do
      host = FactoryGirl.create(:host)
      custom_button = FactoryGirl.create(:custom_button, :applies_to_class => "Host")
      d = FactoryGirl.create(:dialog, :label => "Some Label")
      dt = FactoryGirl.create(:dialog_tab, :label => "Some Tab")
      d.add_resource(dt, {:order => 0})
      ra = FactoryGirl.create(:resource_action, :dialog_id => d.id)
      custom_button.resource_action = ra
      custom_button.save
      post :button, :pressed => "custom_button", :id => host.id, :button_id => custom_button.id
      expect(response.status).to eq(200)
      controller.send(:flash_errors?).should_not be_true
    end

    it "when Drift button is pressed" do
      controller.should_receive(:drift_analysis)
      post :button, :pressed => 'common_drift', :format => :js
      controller.send(:flash_errors?).should_not be_true
    end
  end

  context "#create" do
    it "can create a host with custom id and no host name" do
      set_user_privileges
      controller.instance_variable_set(:@breadcrumbs, [])

      controller.instance_variable_set(:@_params, {
        :button   => "add",
        :id       => "new",
        :name     => 'foobar',
        :hostname => nil,
        :custom_1 => 'bar'
      })

      expect_any_instance_of(Host).to receive(:save).and_call_original
      controller.should_receive(:render)
      controller.send(:create)
      expect(response.status).to eq(200)
      #expect(response.body).to match(/window.location.href.*host\/show_list.*foobar.*added/)
    end

    it "doesn't crash when trying to validate a new host" do
      set_user_privileges
      controller.instance_variable_set(:@breadcrumbs, [])
      controller.new

      controller.instance_variable_set(:@_params, {
        :button           => "validate",
        :type             => "default",
        :id               => "new",
        :name             => 'foobar',
        :hostname         => '127.0.0.1',
        :default_userid   => "abc",
        :default_password => "def",
        :default_verify   => "def",
        :user_assigned_os => "linux_generic"
      })
      controller.should_receive(:render)
      controller.send(:create)
      expect(response.status).to eq(200)
    end
  end

  context "#set_record_vars" do
    it "strips leading/trailing whitespace from hostname/ipaddress when adding infra host" do
      set_user_privileges
      controller.instance_variable_set(:@_params, {
        :name     => 'EMS 2',
        :emstype  => 'rhevm',
        :hostname => '  10.10.10.10  '
      })
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
      controller.stub(:get_view)
      get :guest_applications, :id => @host.id
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
        :numvcpus         => 2,
        :cores_per_socket => 4,
        :logical_cpus     => 8
      )
    )

    get :show, :id => host.id

    expect(response.status).to eq(200)
    expect(response).to render_template('host/show')
  end
end

describe VmCloudController do
  include CompressedIds

  let(:vm_openstack) do
    FactoryGirl.create(:vm_openstack,
                       :ext_management_system => FactoryGirl.create(:ems_openstack))
  end
  before(:each) do
    stub_user(:features => :all)
    session[:settings] = {:views => {:treesize => 20}}
    EvmSpecHelper.create_guid_miq_server_zone
  end

  # All of the x_button is a suplement for Rails routes that is written in
  # controller.
  #
  # You pass in query param 'pressed' and from that the actual route is
  # determined.
  #
  # So we need a test for each possible value of 'presses' until all this is
  # converted into proper routes and test is changed to test the new routes.
  describe 'x_button' do
    before do
      ApplicationController.handle_exceptions = true
    end

    context 'for allowed actions' do
      ApplicationController::Explorer::X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
        prefixes = ["image", "instance"]
        prefixes.each do |prefix|
          actual_action = "#{prefix}_#{action_name}"
          actual_method = [:s1, :s2].include?(method) ? actual_action : method.to_s

          it "calls the appropriate method: '#{actual_method}' for action '#{actual_action}'" do
            expect(controller).to receive(actual_method)
            get :x_button, :params => { :id => nil, :pressed => actual_action }
          end
        end
      end
    end

    context 'for an unknown action' do
      render_views

      it 'exception is raised for unknown action' do
        EvmSpecHelper.create_guid_miq_server_zone
        get :x_button, :params => { :id => nil, :pressed => 'random_dude', :format => :html }
        expect(response).to render_template('layouts/exception')
        expect(response.body).to include('Action not implemented')
      end
    end
  end

  context "with rendered views" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      get :explorer
    end

    render_views

    it 'can render the explorer' do
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end

    it 'can open instance resize tab' do
      post :explorer
      expect(response.status).to eq(200)
      allow(controller).to receive(:x_node).and_return("v-#{vm_openstack.compressed_id}")

      post :x_button, :params => {:pressed => 'instance_resize', :id => vm_openstack.id}
      expect(response.status).to eq(200)
      expect(response).to render_template(:partial => 'vm_common/_resize')
    end

    it 'can resize an instance' do
      flavor = FactoryGirl.create(:flavor_openstack)
      allow(controller).to receive(:load_edit).and_return(true)
      allow(controller).to receive(:previous_breadcrumb_url).and_return("/vm_cloud/explorer")
      controller.instance_variable_set(:@edit,
                                       :new      => {:flavor => flavor.id},
                                       :explorer => false)
      expect_any_instance_of(VmCloud).to receive(:resize).with(flavor)
      post :resize_vm, :params => {
        :button => 'submit',
        :id     => vm_openstack.id
      }
      expect(response.status).to eq(200)
    end

    it 'can open instance live migrate tab' do
      post :explorer
      expect(response.status).to eq(200)
      allow(controller).to receive(:x_node).and_return("v-#{vm_openstack.compressed_id}")

      post :x_button, :params => {:pressed => 'instance_live_migrate', :id => vm_openstack.id}
      expect(response.status).to eq(200)
      expect(response).to render_template(:partial => 'vm_common/_live_migrate')
    end

    it 'can live migrate an instance' do
      allow(controller).to receive(:load_edit).and_return(true)
      allow(controller).to receive(:previous_breadcrumb_url).and_return("/vm_cloud/explorer")
      controller.instance_variable_set(:@edit,
                                       :new      => {},
                                       :explorer => false)
      expect_any_instance_of(VmCloud).to receive(:live_migrate)
      post :live_migrate_vm, :params => {
        :button => 'submit',
        :id     => vm_openstack.id
      }
      expect(response.status).to eq(200)
    end

    it 'can open instance evacuate tab' do
      post :explorer
      expect(response.status).to eq(200)
      allow(controller).to receive(:x_node).and_return("v-#{vm_openstack.compressed_id}")

      post :x_button, :params => {:pressed => 'instance_evacuate', :id => vm_openstack.id}
      expect(response.status).to eq(200)
      expect(response).to render_template(:partial => 'vm_common/_evacuate')
    end

    it 'can evacuate an instance' do
      allow(controller).to receive(:load_edit).and_return(true)
      allow(controller).to receive(:previous_breadcrumb_url).and_return("/vm_cloud/explorer")
      controller.instance_variable_set(:@edit,
                                       :new      => {},
                                       :explorer => false)
      expect_any_instance_of(VmCloud).to receive(:evacuate)
      post :evacuate_vm, :params => {
        :button => 'submit',
        :id     => vm_openstack.id
      }
      expect(response.status).to eq(200)
    end

    it 'can open the instance Ownership form' do
      post :explorer
      expect(response.status).to eq(200)
      post :x_button, :params => { :pressed => 'instance_ownership', :id => vm_openstack.id }
      expect(response.status).to eq(200)
      expect(response).to render_template(:partial => 'shared/views/_ownership')
    end

    it 'can open the instance Ownership form from a list' do
      post :explorer
      expect(response.status).to eq(200)
      post :x_button, :params => { :pressed => 'instance_ownership', "check_#{ApplicationRecord.compress_id(vm_openstack.id)}" => "1"}
      expect(response.status).to eq(200)
      expect(response).to render_template(:partial => 'shared/views/_ownership')
    end

    context "skip or drop breadcrumb" do
      subject { controller.instance_variable_get(:@breadcrumbs) }

      it 'skips dropping a breadcrumb when a button action is executed' do
        ApplicationController.handle_exceptions = true

        post :x_button, :params => { :id => nil, :pressed => 'instance_ownership' }
        expect(subject).to eq([{:name => "Instances", :url => "/vm_cloud/explorer"}])
      end

      it 'drops a breadcrumb when an action allowing breadcrumbs is executed' do
        post :accordion_select, :params => { :id => "images_filter" }
        expect(subject).to eq([{:name => "Images", :url => "/vm_cloud/explorer"}])
      end
    end
  end

  context "#parse error messages" do
    it "simplifies fog error message" do
      raw_msg = "Expected(200) <=> Actual(400 Bad Request)\nexcon.error.response\n  :body          => "\
                "\"{\\\"badRequest\\\": {\\\"message\\\": \\\"Keypair data is invalid: failed to generate "\
                "fingerprint\\\", \\\"code\\\": 400}}\"\n  :cookies       => [\n  ]\n  :headers       => {\n "\
                "\"Content-Length\"       => \"99\"\n    \"Content-Type\"         => \"application/json; "\
                "charset=UTF-8\"\n    \"Date\"                 => \"Mon, 02 May 2016 08:15:51 GMT\"\n ..."\
                ":reason_phrase => \"Bad Request\"\n  :remote_ip     => \"10....\"\n  :status        => 400\n  "\
                ":status_line   => \"HTTP/1.1 400 Bad Request\\r\\n\"\n"
      expect(subject.send(:get_error_message_from_fog, raw_msg)).to eq "Keypair data is invalid: failed to generate "\
                                                                       "fingerprint"
    end
  end
end

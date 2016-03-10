describe OrchestrationStackController do
  let(:user) { FactoryGirl.create(:user_with_group) }

  before(:each) do
    set_user_privileges user
    EvmSpecHelper.create_guid_miq_server_zone
  end

  render_views

  describe '#show' do
    let(:record) { FactoryGirl.create(:orchestration_stack_cloud) }

    before do
      session[:settings] = {
        :views => {:manageiq_providers_cloudmanager_vm => "grid"}
      }
      get :show, :params => {:id => record.id, :display => "instances"}
    end

    it 'does not render compliance check and comparison buttons' do
      expect(response.body).not_to include('instance_check_compliance')
      expect(response.body).not_to include('instance_compare')
    end

    it "renders the listnav" do
      expect(response.status).to eq(200)
      expect(response.status).to render_template(:partial => "layouts/listnav/_orchestration_stack")
    end
  end
end

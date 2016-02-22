describe OrchestrationStackController do
  let(:user) { FactoryGirl.create(:user_with_group) }

  before(:each) do
    set_user_privileges user
    EvmSpecHelper.create_guid_miq_server_zone
  end

  render_views

  context 'show instances' do
    let(:record) { FactoryGirl.create(:orchestration_stack) }

    before do
      session[:settings] = {
        :views => {:manageiq_providers_cloudmanager_vm => "grid"}
      }
    end

    it 'does not renders compliance check and comparison buttons' do
      get :show, :params => { :id => record.id, :display => "instances" }
      expect(response.body).not_to include('instance_check_compliance')
      expect(response.body).not_to include('instance_compare')
    end
  end
end

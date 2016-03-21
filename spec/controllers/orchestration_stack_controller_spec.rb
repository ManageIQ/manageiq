describe OrchestrationStackController do
  let(:user) { FactoryGirl.create(:user_with_group) }

  before(:each) do
    set_user_privileges user
    EvmSpecHelper.create_guid_miq_server_zone
  end

  render_views

  describe '#show' do
    context "instances" do
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

    context "orchestration templates" do
      let(:record) { FactoryGirl.create(:orchestration_stack_cloud_with_template) }

      before do
        session[:settings] = {
          :views => {:manageiq_providers_cloudmanager_vm => "grid"}
        }
        get :show, :params => {:id => record.id, :display => "stack_orchestration_template"}
      end

      it "renders the listnav" do
        expect(response.status).to eq(200)
        expect(response.status).to render_template(:partial => "layouts/listnav/_orchestration_stack")
      end

      it "renders the orchestration template details" do
        expect(response.status).to eq(200)
        expect(response.status).to render_template(:partial => "orchestration_stack/_stack_orchestration_template")
      end
    end
  end

  describe "#button" do
    context "make stack's orchestration template orderable" do
      it "won't allow making stack's orchestration template orderable when already orderable" do
        record = FactoryGirl.create(:orchestration_stack_cloud_with_template)
        post :button, :params => {:id => record.id, :pressed => "make_ot_orderable"}
        expect(record.orchestration_template.orderable?).to be_truthy
        expect(response.status).to eq(200)
        expect(response.status).to render_template(:partial => "layouts/_flash_msg")
        expect(assigns(:flash_array).first[:message]).to include('is already orderable')
      end

      it "makes stack's orchestration template orderable" do
        record = FactoryGirl.create(:orchestration_stack_amazon_with_non_orderable_template)
        post :button, :params => {:id => record.id, :pressed => "make_ot_orderable"}
        expect(record.orchestration_template.orderable?).to be_falsey
        expect(response.status).to eq(200)
        expect(response.status).to render_template(:partial => "layouts/_flash_msg")
        expect(assigns(:flash_array).first[:message]).to include('is now orderable')
      end
    end
  end
end

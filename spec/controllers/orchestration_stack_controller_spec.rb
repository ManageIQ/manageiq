describe OrchestrationStackController do
  let!(:user) { stub_user(:features => :all) }

  before(:each) do
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
        expect(response).to render_template(:partial => "layouts/listnav/_orchestration_stack")
      end
    end

    context "infra" do
      let(:record) { FactoryGirl.create(:orchestration_stack_openstack_infra) }

      before do
        session[:settings] = {
          :views => {:manageiq_providers_cloudmanager_vm => "grid"}
        }
        get :show, :params => {:id => record.id}
      end

      it 'infra does not show deleted error' do
        expect(assigns(:flash_array)).to be_nil
      end

      it "renders the listnav" do
        expect(response.status).to eq(200)
        expect(response).to render_template(:partial => "layouts/listnav/_orchestration_stack")
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
        expect(response).to render_template(:partial => "layouts/listnav/_orchestration_stack")
      end

      it "renders the orchestration template details" do
        expect(response.status).to eq(200)
        expect(response).to render_template(:partial => "orchestration_stack/_stack_orchestration_template")
      end
    end
  end

  describe "#show_list" do
    context "orchestration stack listing" do
      before do
        get :show_list
      end

      it "correctly constructs breadcrumb url" do
        expect(session[:breadcrumbs]).not_to be_empty
        expect(session[:breadcrumbs].first[:url]).to eq("/orchestration_stack/show_list")
      end
    end

    context "orchestration stack listing hides ansible jobs" do
      before do
        @os_cloud  = FactoryGirl.create(:orchestration_stack_cloud, :name => "cloudstack1")
        @os_infra  = FactoryGirl.create(:orchestration_stack_openstack_infra, :name => "infrastack1")
        @tower_job = FactoryGirl.create(:ansible_tower_job, :name => "towerjob1")

        get :show_list
      end

      it "hides ansible jobs" do
        expect(response.body).to include(@os_cloud.name)
        expect(response.body).to include(@os_infra.name)
        expect(response.body).not_to include(@tower_job.name)
      end
    end
  end

  describe "#stacks_ot_info" do
    it "returns all the orchestration template attributes" do
      stack = FactoryGirl.create(:orchestration_stack_cloud_with_template)
      get :stacks_ot_info, :id => stack.id
      expect(response.status).to eq(200)
      ret = JSON.parse(response.body)
      expect(ret).to have_key('template_id')
      expect(ret).to have_key('template_name')
      expect(ret).to have_key('template_description')
      expect(ret).to have_key('template_draft')
      expect(ret).to have_key('template_content')
    end
  end

  describe "#stacks_ot_copy" do
    let(:record) { FactoryGirl.create(:orchestration_stack_cloud_with_template) }

    it "correctly cancels the orchestration template copying form" do
      post :stacks_ot_copy, :params => {:id => record.id, :button => "cancel"}
      expect(response.status).to eq(200)
      expect(response).to render_template(:partial => "layouts/_flash_msg")
      expect(assigns(:flash_array).first[:message]).to include('was cancelled')
      expect(response).to render_template(:partial => "orchestration_stack/_stack_orchestration_template")
    end

    it "correctly redirects to catalog controller after template copy submission" do
      post :stacks_ot_copy, :params => {
        :button              => "add",
        :templateId          => record.orchestration_template.id,
        :templateName        => "new name",
        :templateDescription => "new description",
        :templateDraft       => "true",
        :templateContent     => File.read('spec/fixtures/orchestration_templates/cfn_parameters.json')}
      expect(response.status).to eq(200)
      expect(response.body).to include("window.location.href")
      expect(response.body).to include("/catalog/ot_show/")
    end
  end

  describe "#button" do
    context "make stack's orchestration template orderable" do
      it "won't allow making stack's orchestration template orderable when already orderable" do
        record = FactoryGirl.create(:orchestration_stack_cloud_with_template)
        post :button, :params => {:id => record.id, :pressed => "make_ot_orderable"}
        expect(record.orchestration_template.orderable?).to be_truthy
        expect(response.status).to eq(200)
        expect(response).to render_template(:partial => "layouts/_flash_msg")
        expect(assigns(:flash_array).first[:message]).to include('is already orderable')
      end

      it "makes stack's orchestration template orderable" do
        record = FactoryGirl.create(:orchestration_stack_amazon_with_non_orderable_template)
        post :button, :params => {:id => record.id, :pressed => "make_ot_orderable"}
        expect(record.orchestration_template.orderable?).to be_falsey
        expect(response.status).to eq(200)
        expect(response).to render_template(:partial => "layouts/_flash_msg")
        expect(assigns(:flash_array).first[:message]).to include('is now orderable')
      end
    end

    context "copy stack's orchestration template as orderable" do
      it "won't allow copying stack's orchestration template orderable when already orderable" do
        record = FactoryGirl.create(:orchestration_stack_cloud_with_template)
        post :button, :params => {:id => record.id, :pressed => "orchestration_template_copy"}
        expect(record.orchestration_template.orderable?).to be_truthy
        expect(response.status).to eq(200)
        expect(response).to render_template(:partial => "layouts/_flash_msg")
        expect(assigns(:flash_array).first[:message]).to include('is already orderable')
      end

      it "renders orchestration template copying form" do
        record = FactoryGirl.create(:orchestration_stack_amazon_with_non_orderable_template)
        post :button, :params => {:id => record.id, :pressed => "orchestration_template_copy"}
        expect(record.orchestration_template.orderable?).to be_falsey
        expect(response.status).to eq(200)
        expect(response).to render_template(:partial => "orchestration_stack/_copy_orchestration_template")
      end
    end

    context "view stack's orchestration template in catalog" do
      it "redirects to catalog controller" do
        record = FactoryGirl.create(:orchestration_stack_cloud_with_template)
        post :button, :params => {:id => record.id, :pressed => "orchestration_templates_view"}
        expect(response.status).to eq(200)
        expect(response.body).to include("window.location.href")
        expect(response.body).to include("/catalog/ot_show/")
      end
    end

    context "retire orchestration stack" do
      it "set retirement date redirects to retirement screen" do
        record = FactoryGirl.create(:orchestration_stack_cloud)
        post :button, :params => {:miq_grid_checks => record.id, :pressed => "orchestration_stack_retire"}
        expect(response.status).to eq(200)
        expect(controller.send(:flash_errors?)).not_to be_truthy
        expect(response.body).to include('window.location.href')
      end

      it "retires the orchestration stack now" do
        record = FactoryGirl.create(:orchestration_stack_cloud)
        session[:orchestration_stack_lastaction] = 'show_list'
        post :button, :params => {:miq_grid_checks => record.id, :pressed => "orchestration_stack_retire_now"}
        expect(response.status).to eq(200)
        expect(controller.send(:flash_errors?)).not_to be_truthy
      end
    end
  end
end

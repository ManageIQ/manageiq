RSpec.describe 'Orchestration Template API' do
  let(:ems) { FactoryGirl.create(:ext_management_system) }

  context 'orchestration_template index' do
    it 'can list the orchestration_template' do
      FactoryGirl.create(:orchestration_template_cfn_with_content)
      FactoryGirl.create(:orchestration_template_hot_with_content)
      FactoryGirl.create(:orchestration_template_vnfd_with_content)

      api_basic_authorize collection_action_identifier(:orchestration_templates, :read, :get)
      run_get(orchestration_templates_url)
      expect_query_result(:orchestration_templates, 3, 3)
    end
  end

  context 'orchestration_template create' do
    let :request_body_hot do
      {:name      => "OrchestrationTemplateHot1",
       :type      => "OrchestrationTemplateHot",
       :orderable => true,
       :content   => ""}
    end

    let :request_body_cfn do
      {:name      => "OrchestrationTemplateCfn1",
       :type      => "OrchestrationTemplateCfn",
       :orderable => true,
       :content   => ""}
    end

    let :request_body_vnfd do
      {:name      => "OrchestrationTemplateVnfd1",
       :type      => "OrchestrationTemplateVnfd",
       :ems_id    => ems.id,
       :orderable => true,
       :content   => ""}
    end

    it 'rejects creation without appropriate role' do
      api_basic_authorize

      run_post(orchestration_templates_url, request_body_hot)

      expect(response).to have_http_status(:forbidden)
    end

    it 'supports single HOT orchestration_template creation' do
      api_basic_authorize collection_action_identifier(:orchestration_templates, :create)

      expect do
        run_post(orchestration_templates_url, request_body_hot)
      end.to change(OrchestrationTemplateHot, :count).by(1)
    end

    it 'supports single CFN orchestration_template creation' do
      api_basic_authorize collection_action_identifier(:orchestration_templates, :create)

      expect do
        run_post(orchestration_templates_url, request_body_cfn)
      end.to change(OrchestrationTemplateCfn, :count).by(1)
    end

    it 'supports single VNFd orchestration_template creation' do
      api_basic_authorize collection_action_identifier(:orchestration_templates, :create)

      expect do
        run_post(orchestration_templates_url, request_body_vnfd)
      end.to change(OrchestrationTemplateVnfd, :count).by(1)
    end

    it 'supports orchestration_template creation via action' do
      api_basic_authorize collection_action_identifier(:orchestration_templates, :create)

      expect do
        run_post(orchestration_templates_url, gen_request(:create, request_body_hot))
      end.to change(OrchestrationTemplateHot, :count).by(1)
    end

    it 'rejects a request with an id' do
      api_basic_authorize collection_action_identifier(:orchestration_templates, :create)

      run_post(orchestration_templates_url, request_body_hot.merge(:id => 1))

      expect_bad_request(/Resource id or href should not be specified/)
    end
  end

  context 'orchestration_template edit' do
    it 'supports single orchestration_template edit' do
      hot = FactoryGirl.create(:orchestration_template_hot_with_content, :name => "New Hot Template")

      api_basic_authorize collection_action_identifier(:orchestration_templates, :edit)

      edited_name = "Edited Hot Template"
      run_post(orchestration_templates_url(hot.id), gen_request(:edit, :name => edited_name))

      expect(hot.reload.name).to eq(edited_name)
    end
  end

  context 'orchestration_template delete' do
    it 'supports single orchestration_template delete' do
      api_basic_authorize collection_action_identifier(:orchestration_templates, :delete)

      cfn = FactoryGirl.create(:orchestration_template_cfn_with_content)

      api_basic_authorize collection_action_identifier(:orchestration_templates, :delete)

      run_delete(orchestration_templates_url(cfn.id))

      expect(response).to have_http_status(:no_content)
      expect(OrchestrationTemplate.exists?(cfn.id)).to be_falsey
    end

    it 'supports multiple orchestration_template delete' do
      api_basic_authorize collection_action_identifier(:orchestration_templates, :delete)

      cfn = FactoryGirl.create(:orchestration_template_cfn_with_content)
      hot = FactoryGirl.create(:orchestration_template_hot_with_content)

      run_post(orchestration_templates_url,
               gen_request(:delete, [{'id' => cfn.id}, {'id' => hot.id}]))

      expect(OrchestrationTemplate.exists?(cfn.id)).to be_falsey
      expect(OrchestrationTemplate.exists?(hot.id)).to be_falsey
    end
  end
end

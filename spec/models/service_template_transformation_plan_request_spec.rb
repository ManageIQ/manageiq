describe ServiceTemplateTransformationPlanRequest do
  let(:vms) { Array.new(3) { FactoryGirl.create(:vm_or_template) } }
  let(:vm_requests) do
    [ServiceResource::STATUS_QUEUED, ServiceResource::STATUS_FAILED, ServiceResource::STATUS_APPROVED].zip(vms).collect do |status, vm|
      ServiceResource.new(:resource => vm, :status => status)
    end
  end

  let(:plan) { FactoryGirl.create(:service_template_transformation_plan, :service_resources => vm_requests) }
  let(:request) { FactoryGirl.create(:service_template_transformation_plan_request, :source => plan) }

  describe '#requested_task_idx' do
    it 'selects approved vm requests' do
      expect(request.requested_task_idx.first).to have_attributes(:resource => vms[2], :status => ServiceResource::STATUS_APPROVED)
    end
  end

  describe 'customize_request_task_attributes' do
    it 'sets the source option to be the vm in the vm_request' do
      req_task_attrs = {}
      request.customize_request_task_attributes(req_task_attrs, vm_requests[0])
      expect(req_task_attrs[:source]).to eq(vms[0])
    end
  end

  describe '#source_vms' do
    it 'selects queued and failed vm in the request' do
      expect(request.source_vms).to match_array([vms[0].id, vms[1].id])
    end
  end

  describe '#validate_conversion_hosts' do
    context 'no conversion host exists in EMS' do
      let(:dst_ems) { FactoryGirl.create(:ext_management_system) }
      let(:src_cluster) { FactoryGirl.create(:ems_cluster) }
      let(:dst_cluster) { FactoryGirl.create(:ems_cluster, :ext_management_system => dst_ems) }

      let(:mapping) do
        FactoryGirl.create(
          :transformation_mapping,
          :transformation_mapping_items => [TransformationMappingItem.new(:source => src_cluster, :destination => dst_cluster)]
        )
      end

      let(:catalog_item_options) do
        {
          :name        => 'Transformation Plan',
          :description => 'a description',
          :config_info => {
            :transformation_mapping_id => mapping.id,
            :actions                   => [
              {:vm_id => vms.first.id.to_s, :pre_service => false, :post_service => false},
              {:vm_id => vms.last.id.to_s, :pre_service => false, :post_service => false},
            ],
          }
        }
      end

      let(:plan) { ServiceTemplateTransformationPlan.create_catalog_item(catalog_item_options) }
      let(:request) { FactoryGirl.create(:service_template_transformation_plan_request, :source => plan) }

      it 'returns false' do
        host = FactoryGirl.create(:host, :ext_management_system => FactoryGirl.create(:ext_management_system, :zone => FactoryGirl.create(:zone)))
        conversion_host = FactoryGirl.create(:conversion_host, :resource => host)
        expect(request.validate_conversion_hosts).to be false
      end
    end

    context 'conversion host exists in EMS and resource is a Host' do
      let(:dst_ems) { FactoryGirl.create(:ems_redhat) }
      let(:src_cluster) { FactoryGirl.create(:ems_cluster) }
      let(:dst_cluster) { FactoryGirl.create(:ems_cluster, :ext_management_system => dst_ems) }

      let(:mapping) do
        FactoryGirl.create(
          :transformation_mapping,
          :transformation_mapping_items => [TransformationMappingItem.new(:source => src_cluster, :destination => dst_cluster)]
        )
      end

      let(:catalog_item_options) do
        {
          :name        => 'Transformation Plan',
          :description => 'a description',
          :config_info => {
            :transformation_mapping_id => mapping.id,
            :actions                   => [
              {:vm_id => vms.first.id.to_s, :pre_service => false, :post_service => false},
              {:vm_id => vms.last.id.to_s, :pre_service => false, :post_service => false},
            ],
          }
        }
      end

      let(:plan) { ServiceTemplateTransformationPlan.create_catalog_item(catalog_item_options) }
      let(:request) { FactoryGirl.create(:service_template_transformation_plan_request, :source => plan) }

      it 'returns true' do
        host = FactoryGirl.create(:host, :ext_management_system => dst_ems, :ems_cluster => dst_cluster)
        conversion_host = FactoryGirl.create(:conversion_host, :resource => host)
        expect(request.validate_conversion_hosts).to be true
      end
    end

    context 'conversion host exists in EMS and resource is a Vm' do
      let(:dst_ems) { FactoryGirl.create(:ems_openstack) }
      let(:src_cluster) { FactoryGirl.create(:ems_cluster) }
      let(:dst_cloud_tenant) { FactoryGirl.create(:cloud_tenant, :ext_management_system => dst_ems) }

      let(:mapping) do
        FactoryGirl.create(
          :transformation_mapping,
          :transformation_mapping_items => [TransformationMappingItem.new(:source => src_cluster, :destination => dst_cloud_tenant)]
        )
      end

      let(:catalog_item_options) do
        {
          :name        => 'Transformation Plan',
          :description => 'a description',
          :config_info => {
            :transformation_mapping_id => mapping.id,
            :actions                   => [
              {:vm_id => vms.first.id.to_s, :pre_service => false, :post_service => false},
              {:vm_id => vms.last.id.to_s, :pre_service => false, :post_service => false},
            ],
          }
        }
      end

      let(:plan) { ServiceTemplateTransformationPlan.create_catalog_item(catalog_item_options) }
      let(:request) { FactoryGirl.create(:service_template_transformation_plan_request, :source => plan) }

      it 'returns true' do
        vm = FactoryGirl.create(:vm_openstack, :ext_management_system => dst_ems, :cloud_tenant => dst_cloud_tenant)
        conversion_host = FactoryGirl.create(:conversion_host, :resource => vm)
        expect(request.validate_conversion_hosts).to be true
      end
    end
  end

  describe '#validate_vm' do
    it { expect(request.validate_vm(vms[0].id)).to be_truthy }
  end

  describe '#approve_vm' do
    it 'turns the status to Approved' do
      request.approve_vm(vms[0].id)
      expect(ServiceResource.find_by(:resource => vms[0]).status).to eq(ServiceResource::STATUS_APPROVED)
    end
  end

  context "when request gets canceled" do
    before { request.cancel }

    it "cancelation_status is set to requested" do
      expect(request.cancelation_status).to eq(MiqRequest::CANCEL_STATUS_REQUESTED)
      expect(request.cancel_requested?).to be_truthy
      expect(request.canceling?).to be_falsey
      expect(request.canceled?).to be_falsey
    end

    it "marks request as finished in error" do
      request.send(:do_cancel)
      expect(request.cancelation_status).to eq(MiqRequest::CANCEL_STATUS_FINISHED)
      expect(request.request_state).to eq('finished')
      expect(request.status).to eq('Error')
      expect(request.message).to eq('Request is canceled by user.')
    end
  end
end

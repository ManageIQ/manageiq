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

  describe '#validate_vm' do
    it { expect(request.validate_vm(vms[0].id)).to be_truthy }
  end

  describe '#approve_vm' do
    it 'turns the status to Approved' do
      request.approve_vm(vms[0].id)
      expect(ServiceResource.find_by(:resource => vms[0]).status).to eq(ServiceResource::STATUS_APPROVED)
    end
  end
end

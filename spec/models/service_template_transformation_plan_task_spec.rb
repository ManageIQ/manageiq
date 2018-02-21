describe ServiceTemplateTransformationPlanTask do
  describe '.base_model' do
    it { expect(described_class.base_model).to eq(ServiceTemplateTransformationPlanTask) }
  end

  describe '#after_request_task_create' do
    it 'does not create child tasks' do
      allow(subject).to receive(:source).and_return(double('vm', :name => 'any'))
      expect(subject).not_to receive(:create_child_tasks)
      expect(subject).to receive(:update_attributes).with(hash_including(:description))
      subject.after_request_task_create
    end
  end

  context 'populated request and task' do
    let(:src) { FactoryGirl.create(:ems_cluster) }
    let(:dst) { FactoryGirl.create(:ems_cluster) }
    let(:mapping) do
      FactoryGirl.create(
        :transformation_mapping,
        :transformation_mapping_items => [TransformationMappingItem.new(:source => src, :destination => dst)]
      )
    end

    let(:catalog_item_options) do
      {
        :name        => 'Transformation Plan',
        :description => 'a description',
        :config_info => {
          :transformation_mapping_id => mapping.id,
          :vm_ids                    => [FactoryGirl.create(:vm_or_template).id],
        }
      }
    end

    let(:plan) { ServiceTemplateTransformationPlan.create_catalog_item(catalog_item_options) }

    let(:request) { FactoryGirl.create(:service_template_transformation_plan_request, :source => plan) }
    let(:task) { FactoryGirl.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan') }

    describe '#resource_action' do
      it 'has a resource action points to the entry point for transformation' do
        expect(task.resource_action).to have_attributes(
          :action => 'Provision',
          :fqname => ServiceTemplateTransformationPlan.default_provisioning_entry_point(nil)
        )
      end
    end

    describe '#transformation_destination' do
      it { expect(task.transformation_destination(src)).to eq(dst) }
    end

    describe '#update_transformation_progress' do
      it 'saves the progress in options' do
        task.update_transformation_progress(:vm_percent => '80')
        expect(task.options[:progress]).to eq(:vm_percent => '80')
      end
    end
  end
end

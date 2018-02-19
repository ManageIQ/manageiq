describe ServiceTemplateTransformationPlan do
  subject { FactoryGirl.create(:service_template_transformation_plan) }

  describe '#request_class' do
    it { expect(subject.request_class).to eq(ServiceTemplateTransformationPlanRequest) }
  end

  describe '#request_type' do
    it { expect(subject.request_type).to eq("transformation_plan") }
  end

  describe '#validate_order' do
    it 'always allows a plan to be ordered' do
      expect(subject.validate_order).to be_truthy
    end
  end

  let(:transformation_mapping) { FactoryGirl.create(:transformation_mapping) }
  let(:vm1) { FactoryGirl.create(:vm_or_template) }
  let(:vm2) { FactoryGirl.create(:vm_or_template) }

  let(:catalog_item_options) do
    {
      :name        => 'Transformation Plan',
      :description => 'a description',
      :config_info => {
        :transformation_mapping_id => transformation_mapping.id,
        :vm_ids                    => [vm1.id, vm2.id],
      }
    }
  end

  describe '.create_catalog_item' do
    it 'creates and returns a transformation plan' do
      service_template = described_class.create_catalog_item(catalog_item_options)

      expect(service_template.name).to eq('Transformation Plan')
      expect(service_template.transformation_mapping).to eq(transformation_mapping)
      expect(service_template.vm_requests.collect(&:resource)).to match_array([vm1, vm2])
      expect(service_template.vm_requests.collect(&:status)).to eq(%w(Queued Queued))
      expect(service_template.config_info).to eq(catalog_item_options[:config_info])
      expect(service_template.resource_actions.first).to have_attributes(
        :action => 'Provision',
        :fqname => described_class.default_provisioning_entry_point(nil)
      )
    end

    it 'requires a transformation mapping' do
      catalog_item_options[:config_info].delete(:transformation_mapping_id)

      expect do
        described_class.create_catalog_item(catalog_item_options)
      end.to raise_error(StandardError, 'Must provide an existing transformation mapping')
    end

    it 'requires selected vms' do
      catalog_item_options[:config_info].delete(:vm_ids)

      expect do
        described_class.create_catalog_item(catalog_item_options)
      end.to raise_error(StandardError, 'Must select a list of valid vms')
    end
  end
end

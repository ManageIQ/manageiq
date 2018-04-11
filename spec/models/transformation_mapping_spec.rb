describe TransformationMapping do
  let(:src) { FactoryGirl.create(:ems_cluster) }
  let(:dst) { FactoryGirl.create(:ems_cluster) }

  let(:mapping) do
    FactoryGirl.create(
      :transformation_mapping,
      :transformation_mapping_items => [TransformationMappingItem.new(:source => src, :destination => dst)]
    )
  end

  describe '#destination' do
    it "finds the destination" do
      expect(mapping.destination(src)).to eq(dst)
    end

    it "returns nil for unmapped source" do
      expect(mapping.destination(FactoryGirl.create(:ems_cluster))).to be_nil
    end
  end

  describe '#service_templates' do
    let(:plan) { FactoryGirl.create(:service_template_transformation_plan) }
    before { FactoryGirl.create(:service_resource, :resource => mapping, :service_template => plan) }

    it 'finds the transformation plans' do
      expect(mapping.service_templates).to match([plan])
    end
  end
end

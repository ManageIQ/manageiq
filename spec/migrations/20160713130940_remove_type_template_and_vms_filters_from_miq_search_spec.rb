require_migration

describe RemoveTypeTemplateAndVmsFiltersFromMiqSearch do
  let(:miq_search_stub) { migration_stub(:MiqSearch) }

  migration_context :up do
    it "removes Type Template/VMs filters from MiqSearch" do
      filter_1 = miq_search_stub.create!(described_class::TEMPLATE_TYPE_FILTER)
      filter_2 = miq_search_stub.create!(described_class::VMS_TYPE_FILTER)
      filter_3 = miq_search_stub.create!(:name => 'Template/VMs test filter')

      migrate

      filter_1 = miq_search_stub.find_by(:id => filter_1.id)
      filter_2 = miq_search_stub.find_by(:id => filter_2.id)
      filter_3 = miq_search_stub.find_by(:id => filter_3.id)

      expect(filter_1).to be_nil
      expect(filter_2).to be_nil
      expect(filter_3).to_not be_nil
    end
  end

  migration_context :down do
    it "adds Type Template/VMs filters to MiqSearch" do
      migrate

      temp_filter = described_class::TEMPLATE_TYPE_FILTER.dup
      temp_filter.except!(:filter, :search_type)
      filter_1 = miq_search_stub.where(temp_filter).first

      vms_filter = described_class::VMS_TYPE_FILTER.dup
      vms_filter.except!(:filter, :search_type)
      filter_2 = miq_search_stub.where(vms_filter).first

      expect(filter_1).to_not have_attributes(described_class::TEMPLATE_TYPE_FILTER)
      expect(filter_2).to_not have_attributes(described_class::VMS_TYPE_FILTER)
    end
  end
end

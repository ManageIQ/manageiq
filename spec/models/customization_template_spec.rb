RSpec.describe CustomizationTemplate do
  it "doesn't access database when unchanged model is saved" do
    m = FactoryBot.create(:customization_template)
    expect { m.valid? }.not_to make_database_queries
  end

  context "unique name validation" do
    it "doesn't allow same name, same pxe_image_type in same region" do
      pit = FactoryBot.create(:pxe_image_type)
      FactoryBot.create(:customization_template, :name => "fred", :pxe_image_type => pit)
      expect { FactoryBot.create(:customization_template, :name => "fred", :pxe_image_type => pit) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "allows same name, different pxe_image_type in same region" do
      FactoryBot.create(:customization_template, :name => "fred", :pxe_image_type => FactoryBot.create(:pxe_image_type))
      FactoryBot.create(:customization_template, :name => "fred", :pxe_image_type => FactoryBot.create(:pxe_image_type))

      first, second = described_class.all
      expect(first.name).to eq(second.name)
      expect(first.pxe_image_type).to_not eq(second.pxe_image_type)
      expect(ApplicationRecord.id_to_region(first.id)).to eq(ApplicationRecord.id_to_region(second.id))
    end

    it "allows different name, same pxe_image_type in same region" do
      pit = FactoryBot.create(:pxe_image_type)
      FactoryBot.create(:customization_template, :name => "fred", :pxe_image_type => pit)
      FactoryBot.create(:customization_template, :name => "nick", :pxe_image_type => pit)
      expect(described_class.count).to eq(2)

      first, second = described_class.all
      expect(first.name).to_not eq(second.name)
      expect(first.pxe_image_type).to eq(second.pxe_image_type)
      expect(ApplicationRecord.id_to_region(first.id)).to eq(ApplicationRecord.id_to_region(second.id))
    end

    it "allows same name, nil pxe_image_types in different regions (for system seeding)" do
      system_template   = described_class.create!(:system => true, :name => "nick")
      other_template_id = ApplicationRecord.id_in_region(system_template.id, ApplicationRecord.my_region_number + 1)
      described_class.create!(:system => true, :name => "nick", :id => other_template_id)

      first, second = described_class.all
      expect(first.name).to eq(second.name)
      expect(first.pxe_image_type).to be nil
      expect(first.pxe_image_type).to eq(second.pxe_image_type)
      expect(ApplicationRecord.id_to_region(first.id)).to_not eq(ApplicationRecord.id_to_region(second.id))
    end

    it "allows same name, different pxe_image_types in different regions" do
      pit               = FactoryBot.create(:pxe_image_type)
      template          = FactoryBot.create(:customization_template, :name => "nick", :pxe_image_type => pit)
      other_template_id = ApplicationRecord.id_in_region(template.id, MiqRegion.my_region_number + 1)
      other_pit_id      = ApplicationRecord.id_in_region(pit.id, MiqRegion.my_region_number + 1)
      other_pit         = FactoryBot.create(:pxe_image_type, :id => other_pit_id)
      FactoryBot.create(:customization_template, :name => "nick", :pxe_image_type => other_pit, :id => other_template_id)

      first, second = described_class.all
      expect(first.name).to eq(second.name)
      expect(first.pxe_image_type).to_not eq(second.pxe_image_type)
      expect(ApplicationRecord.id_to_region(first.id)).to_not eq(ApplicationRecord.id_to_region(second.id))
    end
  end
end

describe CustomButtonSet do
  context "find_all_by_class_name" do
    it "should return all Service and ServiceTemplate buttons only, when ServiceTemplate class is passed in" do
      set_data = {:applies_to_class => "Service", :group_index => 2}
      button_set1 = FactoryBot.create(:custom_button_set, :name => "set1", :set_data => set_data)
      button_set1.save!

      set_data = {:applies_to_class => "ServiceTemplate", :applies_to_id => 1, :group_index => 1}
      button_set2 = FactoryBot.create(:custom_button_set, :name => "set2", :set_data => set_data)
      button_set2.save!

      set_data = {:applies_to_class => "Vm", :group_index => 3}
      button_set3 = FactoryBot.create(:custom_button_set, :name => "set3", :set_data => set_data)
      button_set3.save!

      button_sets = CustomButtonSet.find_all_by_class_name("ServiceTemplate", 1)
      expect(button_sets.count).to eq(2)

      all_button_sets = CustomButtonSet.all
      expect(all_button_sets.count).to eq(3)
    end
  end

  describe '.filter_with_visibility_expression' do
    let(:vm_1)              { FactoryBot.create(:vm_vmware, :name => 'vm_1') }
    let(:custom_button_1)   { FactoryBot.create(:custom_button, :applies_to => vm_1) }
    let(:miq_expression)    { MiqExpression.new('EQUAL' => {'field' => 'Vm-name', 'value' => "vm_1"}) }
    let(:custom_button_2)   { FactoryBot.create(:custom_button, :applies_to => vm_1, :visibility_expression => miq_expression) }
    let(:set_data)          { {:applies_to_class => "Vm", :button_order => [custom_button_1.id, custom_button_2.id]} }
    let(:custom_button_set) { FactoryBot.create(:custom_button_set, :name => "set_1", :set_data => set_data) }

    before do
      [custom_button_1, custom_button_2].each { |x| custom_button_set.add_member(x) }
    end

    context 'when all CustomButtons#visibility_expression=nil' do
      let(:miq_expression) { nil }

      it 'returns same array CustomButtonSet as input' do
        expect(described_class.filter_with_visibility_expression([custom_button_set], vm_1)).to eq([custom_button_set])
      end
    end

    context 'when any visibility_expression is evaluated to false and any to true' do
      let(:miq_expression_false)   { MiqExpression.new('EQUAL' => {'field' => 'Vm-name', 'value' => "vm_2"}) }
      let(:custom_button_1)        { FactoryBot.create(:custom_button, :applies_to => vm_1, :visibility_expression => miq_expression_false) }
      let(:custom_button_3)        { FactoryBot.create(:custom_button, :applies_to => vm_1, :visibility_expression => miq_expression) }
      let(:custom_button_4)        { FactoryBot.create(:custom_button, :applies_to => vm_1, :visibility_expression => miq_expression) }
      let(:set_data)               { {:applies_to_class => "Vm", :button_order => [custom_button_4.id, custom_button_2.id, custom_button_1.id, custom_button_3.id]} }
      let(:custom_button_set)      { FactoryBot.create(:custom_button_set, :name => "set_1", :set_data => set_data) }

      before do
        [custom_button_3, custom_button_4].each { |x| custom_button_set.add_member(x) }
      end

      it 'returns filtered array of CustomButtonSet and CustomButtons ordered by custom_button_set.set_data[:button_order]' do
        set = described_class.filter_with_visibility_expression([custom_button_set], vm_1).first
        expect(set.set_data[:button_order]).to eq([custom_button_4.id, custom_button_2.id, custom_button_3.id])
      end

      context 'all CustomButtons#visibility_expression are evaluated to false' do
        let(:miq_expression)    { MiqExpression.new('EQUAL' => {'field' => 'Vm-name', 'value' => 'vm_2'}) }
        it 'returns empty array of CustomButtonSet' do
          expect(described_class.filter_with_visibility_expression([custom_button_set], vm_1)).to be_empty
        end
      end
    end
  end

  it "#deep_copy" do
    service_template1 = FactoryBot.create(:service_template)
    service_template2 = FactoryBot.create(:service_template)
    custom_button     = FactoryBot.create(:custom_button, :applies_to => service_template1)
    set_data          = {:applies_to_class => "ServiceTemplate", :button_order => [custom_button.id]}
    custom_button_set = FactoryBot.create(:custom_button_set, :set_data => set_data)

    custom_button_set.add_member(custom_button)
    custom_button_set.deep_copy(:owner => service_template2)

    expect(CustomButton.count).to eq(2)
    expect(CustomButtonSet.count).to eq(2)
  end

  context '#update_children' do
    let(:vm)                { FactoryBot.create(:vm_vmware, :name => 'vm') }
    let(:custom_button_1)   { FactoryBot.create(:custom_button, :applies_to => vm) }
    let(:custom_button_2)   { FactoryBot.create(:custom_button, :applies_to => vm) }
    let(:custom_button_3)   { FactoryBot.create(:custom_button, :applies_to => vm) }
    let(:set_data)          { {:applies_to_class => "Vm", :button_order => [custom_button_1.id, custom_button_2.id]} }
    let(:custom_button_set) { FactoryBot.create(:custom_button_set, :name => "set_1", :set_data => set_data) }

    it "updates children after setting button_order" do
      expect(custom_button_set.children.count).to eq(2)

      custom_button_set.set_data[:button_order] = [
        custom_button_2.id,
        custom_button_3.id,
      ]
      custom_button_set.save!

      expect(custom_button_set.children.count).to eq(2)
      expect(custom_button_set.children).not_to include(custom_button_1)
      expect(custom_button_set.children).to include(custom_button_2)
      expect(custom_button_set.children).to include(custom_button_3)
    end
  end
end

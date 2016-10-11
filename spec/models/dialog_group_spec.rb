describe DialogGroup do
  let(:dialog_group) { FactoryGirl.build(:dialog_group, :label => 'group') }
  context "#validate_children" do

    it "fails without element" do
      expect { dialog_group.save! }
        .to raise_error(ActiveRecord::RecordInvalid, /Box group must have at least one Element/)
    end

    it "validates with at least one element" do
      dialog_group.dialog_fields << FactoryGirl.create(:dialog_field, :label => 'field 1', :name => 'field1')
      expect_any_instance_of(DialogField).to receive(:valid?)
      expect(dialog_group.errors.full_messages).to be_empty
      dialog_group.validate_children
    end
  end

  context "#dialog_fields" do
    # other tests are in dialog_spec.rb
    it "returns [] even when no dialog_tab" do
      expect(dialog_group.dialog_fields).to be_empty
    end
  end

  context '#update_dialog_tabs' do
    before(:each) do
      @dialog_group = FactoryGirl.create(:dialog_group)
      @dialog_fields = FactoryGirl.create_list(:dialog_field, 2)
      @dialog_group.dialog_fields << @dialog_fields
    end

    it 'deletes a dialog tab' do
      fields = [
        { 'id' => @dialog_fields.first.id }
      ]

      expect do
        @dialog_group.update_dialog_fields(fields)
      end.to change(@dialog_group.reload.dialog_fields, :count).by(-1)
    end

    it 'adds a dialog tab' do
      fields = [
        { 'id' => @dialog_fields.first.id },
        { 'id' => @dialog_fields.last.id },
        { 'name' => 'new tab', 'label' => 'new label' }
      ]

      expect do
        @dialog_group.update_dialog_fields(fields)
      end.to change(@dialog_group.reload.dialog_fields, :count).by(1)
    end

    it 'updates a dialog tab' do
      fields = [
        { 'id' => @dialog_fields.first.id, 'name' => 'updated name'},
        { 'id' => @dialog_fields.first.id }
      ]

      expect do
        @dialog_group.update_dialog_fields(fields)
      end.to change(@dialog_fields.first.reload, :name)
    end
  end
end

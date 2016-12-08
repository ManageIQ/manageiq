describe TreeBuilderBelongsToVat do
  before do
    login_as FactoryGirl.create(:user_with_group, :role => "operator", :settings => {})
    FactoryGirl.create(:ems_redhat)
    FactoryGirl.create(:ems_google_network)
  end

  let(:edit) { nil }
  let(:group) { FactoryGirl.create(:miq_group) }
  let(:ems_folder) { FactoryGirl.create(:ems_folder) }
  let(:subfolder) do
    subfolder = FactoryGirl.create(:ems_folder, :name => 'vm')
    subfolder.with_relationship_type("ems_metadata") { subfolder.add_child(ems_folder) }
    subfolder
  end
  let(:folder) { FactoryGirl.create(:ems_folder) }
  let(:ems_azure_network) do
    ems_azure_network = FactoryGirl.create(:ems_azure_network)
    ems_azure_network.with_relationship_type("ems_metadata") { ems_azure_network.add_child(folder) }
    ems_azure_network
  end
  let(:datacenter) do
    datacenter = FactoryGirl.create(:datacenter)
    datacenter.with_relationship_type("ems_metadata") { datacenter.add_folder(subfolder) }
    datacenter
  end

  subject do
    described_class.new(:vat,
                        :vat_tree,
                        {:trees => {}},
                        true,
                        :edit     => edit,
                        :filters  => {},
                        :group    => group,
                        :selected => {})
  end

  describe '#tree_init_options' do
    it 'sets tree options correctly' do
      expect(subject.send(:tree_init_options, :vat)).to eq(:full_ids             => true,
                                                           :add_root             => false,
                                                           :lazy                 => false,
                                                           :checkable_checkboxes => edit.present?,
                                                           :selected             => {})
    end
  end

  describe '#set_locals_for_render' do
    it 'set locals for render correctly' do
      locals = subject.send(:set_locals_for_render)
      expect(locals).to include(:id_prefix         => 'vat_',
                                :checkboxes        => true,
                                :check_url         => "/ops/rbac_group_field_changed/#{group.id || "new"}___",
                                :onclick           => false,
                                :oncheck           => edit ? "miqOnCheckUserFilters" : nil,
                                :highlight_changes => true)
    end
  end

  describe '#x_get_tree_datacenter_kids' do
    it 'returns folders' do
      kids = subject.send(:x_get_tree_datacenter_kids, datacenter, false, nil)
      expect(kids).to include(ems_folder)
    end
  end
end

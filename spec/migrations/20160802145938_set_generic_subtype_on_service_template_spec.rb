require_migration

describe SetGenericSubtypeOnServiceTemplate do
  let(:service_template_stub) { migration_stub(:ServiceTemplate) }

  migration_context :up do
    it 'sets generic_subtype to custom on generic Service Templates' do
      st = service_template_stub.create!(:prov_type => 'generic')

      migrate

      expect(st.reload.generic_subtype).to eq('custom')
    end

    it 'skips non-generic Service Templates' do
      st = service_template_stub.create!(:prov_type => 'vmware')

      migrate

      expect(st.reload.generic_subtype).to be_nil
    end
  end

  migration_context :down do
    it 'sets generic_subtype to nil on generic Service Templates' do
      st = service_template_stub.create!(:prov_type => 'generic', :generic_subtype => 'custom')

      migrate

      expect(st.reload.generic_subtype).to be_nil
    end

    it 'skips non-generic Service Templates' do
      st = service_template_stub.create!(:prov_type => 'vmware', :generic_subtype => 'something')

      migrate

      expect(st.reload.generic_subtype).to eq('something')
    end
  end
end

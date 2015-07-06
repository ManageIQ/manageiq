require "spec_helper"
require Rails.root.join("db/migrate/20141021103820_remove_miq_search_vdi_instances.rb")

describe RemoveMiqSearchVdiInstances do
  let(:miq_search_stub) { migration_stub(:MiqSearch) }

  migration_context :up do
    it 'Remove MiqSearch instance for VdiUser' do
      miq_search_stub.create!(:db => 'VdiUser')
      miq_search_stub.create!(:db => 'Vm')

      migrate

      rows = miq_search_stub.all
      expect(rows.length).to   eq(1)
      expect(rows.first.db).to eq('Vm')
    end
  end
end

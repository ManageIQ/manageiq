require_migration

describe RemoveSystemAddSourceToMiqAeNamespace do
  let(:miq_ae_namespace_stub) { migration_stub(:MiqAeNamespace) }

  migration_context :up do
    it "migrates system to source" do
      miq_ae_namespace_stub.create!(:name => 'ManageIQ', :system => true, :parent_id => nil)
      miq_ae_namespace_stub.create!(:name => 'Customer', :system => true, :parent_id => nil)
      miq_ae_namespace_stub.create!(:name => 'Temp', :system => false, :parent_id => nil)

      migrate

      expect(miq_ae_namespace_stub.count).to eq 3
      expect(miq_ae_namespace_stub.find_by_name('ManageIQ').source).to eql("system")
      expect(miq_ae_namespace_stub.find_by_name('Customer').source).to eql("user_locked")
      expect(miq_ae_namespace_stub.find_by_name('Temp').source).to eql("user")
    end
  end

  migration_context :down do
    it "migrates source to system" do
      miq_ae_namespace_stub.create!(:name => 'ManageIQ', :source => "system", :parent_id => nil)
      miq_ae_namespace_stub.create!(:name => 'Customer', :source => "user_locked", :parent_id => nil)
      miq_ae_namespace_stub.create!(:name => 'Temp', :source => "user", :parent_id => nil)

      migrate

      expect(miq_ae_namespace_stub.count).to eq 3
      expect(miq_ae_namespace_stub.find_by_name('ManageIQ').system).to be_truthy
      expect(miq_ae_namespace_stub.find_by_name('Customer').system).to be_truthy
      expect(miq_ae_namespace_stub.find_by_name('Temp').system).to be_falsey
    end
  end
end

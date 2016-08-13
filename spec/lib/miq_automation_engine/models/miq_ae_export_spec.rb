describe MiqAeExport do
  include Spec::Support::AutomationHelper

  describe "#instantiate" do
    let(:tenant1) { FactoryGirl.create(:tenant) }
    let(:tenant2) { FactoryGirl.create(:tenant) }

    before do
      allow(MiqAeExport).to receive(:write_domain).and_return("")
      create_ae_model(:name => "dom1", :tenant => tenant1)
      create_ae_model(:name => "dom2", :tenant => tenant2)
    end

    context "tenant" do
      let(:options) { {'export_dir' => Dir.tmpdir, 'overwrite' => true, 'tenant' => tenant1} }
      it "exports a single domain" do
        obj = MiqAeExport.new('DoM1', options)
        expect(obj).to receive(:write_domain).once
        obj.export
      end

      it "exports multiple domains" do
        obj = MiqAeExport.new('*', options)
        expect(obj).to receive(:write_domain).once
        obj.export
      end

      it "fails to access other tenants domain" do
        expect { MiqAeExport.new('DoM2', options).export }.to raise_exception(MiqAeException::DomainNotAccessible)
      end
    end

    context "root tenant" do
      let(:options) { {'export_dir' => Dir.tmpdir, 'overwrite' => true, 'tenant' => Tenant.root_tenant} }

      before do
        create_ae_model(:name => "root_domain", :tenant => Tenant.root_tenant)
      end

      it "cannot access other tenants domain" do
        expect { MiqAeExport.new('DoM2', options).export }.to raise_exception(MiqAeException::DomainNotAccessible)
      end

      it "with all domains shouldn't fetch other tenants domains" do
        obj = MiqAeExport.new('*', options)
        expect(obj).to receive(:write_domain).once
        obj.export
      end
    end

    context "backup" do
      let(:options) { {'export_dir' => Dir.tmpdir, 'overwrite' => true} }

      before do
        create_ae_model(:name => "root_domain", :tenant => Tenant.root_tenant)
      end

      it "with no tenant specified exports all" do
        obj = MiqAeExport.new('*', options)
        expect(obj).to receive(:write_domain).exactly(3).times
        obj.export
      end
    end
  end
end

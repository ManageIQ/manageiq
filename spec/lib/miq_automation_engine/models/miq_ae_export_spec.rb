require "spec_helper"
include AutomationSpecHelper

describe MiqAeExport do
  before do
    @root_tenant = Tenant.seed
    @tenant1 = FactoryGirl.create(:tenant)
    @tenant2 = FactoryGirl.create(:tenant)
    create_ae_model(:name => "dom1", :tenant => @tenant1)
    create_ae_model(:name => "dom2", :tenant => @tenant2)
    @options = {'export_dir' => Dir.tmpdir, 'overwrite' => true}
  end

  it "export inaccessible domain" do
    hash = @options.merge('tenant' => @tenant1)
    expect { MiqAeExport.new('dom2', hash) }.to raise_exception(MiqAeException::DomainNotAccessible)
  end

  it "export all domains for a tenant" do
    hash = @options.merge('tenant' => @tenant1)
    MiqAeExport.stub(:write_domain).and_return("")
    obj = MiqAeExport.new('*', hash)
    obj.should_receive(:write_domain).once
    obj.export
  end

  it "export a domain as root tenant" do
    hash = @options.merge('tenant' => @root_tenant)
    MiqAeExport.stub(:write_domain).and_return("")
    obj = MiqAeExport.new('dom2', hash)
    obj.should_receive(:write_domain).once
    obj.export
  end

  it "export multiple domain as root tenant" do
    hash = @options.merge('tenant' => @root_tenant)
    MiqAeExport.stub(:write_domain).and_return("")
    obj = MiqAeExport.new('*', hash)
    obj.should_receive(:write_domain).twice
    obj.export
  end
end

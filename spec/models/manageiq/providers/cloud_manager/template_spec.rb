describe TemplateCloud do
  describe "actions" do
    it "#post_create_actions" do
      expect(subject).to receive(:reconnect_events)
      expect(subject).to receive(:classify_with_parent_folder_path)
      expect(MiqEvent).to receive(:raise_evm_event).with(subject, "vm_template", :vm => subject)

      subject.post_create_actions
    end
  end

  let(:root_tenant) do
    Tenant.seed
  end

  let(:default_tenant) do
    root_tenant
    Tenant.default_tenant
  end

  describe "miq_group" do
    let(:user)         { FactoryGirl.create(:user, :userid => 'user', :miq_groups => [tenant_group]) }
    let(:tenant)       { FactoryGirl.build(:tenant, :parent => default_tenant) }
    let(:tenant_users) { FactoryGirl.create(:miq_user_role, :name => "tenant-users") }
    let(:tenant_group) { FactoryGirl.create(:miq_group, :miq_user_role => tenant_users, :tenant => tenant) }
    let(:cloud_template_1) { FactoryGirl.create(:class => "TemplateCloud") }

    it "finds correct tenant id clause when tenant doesn't have source_id" do
      User.current_user = user
      expect(TemplateCloud.tenant_id_clause(user)).to eql ["(vms.template = true AND (vms.tenant_id IN (?) OR vms.publicly_available = true))", [default_tenant.id, tenant.id]]
    end

    it "finds correct tenant id clause when tenant has source_id" do
      User.current_user = user
      tenant.source_id = 1
      expect(TemplateCloud.tenant_id_clause(user)).to eql ["(vms.template = true AND (vms.tenant_id = (?) AND vms.publicly_available = false OR vms.publicly_available = true))", tenant.id]
    end
  end
end

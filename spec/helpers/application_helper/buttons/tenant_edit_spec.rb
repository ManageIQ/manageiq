describe ApplicationHelper::Button::TenantEdit do
  describe '#disabled?' do
    let(:tenant_with_cloud_tenant)    { FactoryGirl.create(:tenant_with_cloud_tenant) }
    let(:tenant_without_cloud_tenant) { FactoryGirl.create(:tenant) }

    before do
      @view_context = setup_view_context_with_sandbox({})
    end

    def tenant_edit_button(tenant)
      described_class.new(@view_context, {}, {'record' => tenant}, {})
    end

    it "disables the button when tenant is created by cloud tenant mapping" do
      expect(tenant_edit_button(tenant_with_cloud_tenant).disabled?).to be_truthy
    end

    it "does not disable the button when tenant is created by cloud tenant mapping" do
      expect(tenant_edit_button(tenant_without_cloud_tenant).disabled?).to be_falsey
    end
  end
end

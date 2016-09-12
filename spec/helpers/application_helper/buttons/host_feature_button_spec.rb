describe ApplicationHelper::Button::HostFeatureButton do
  describe '#visible?' do
    context "record is openstack infra manager" do
      before do
        @record = FactoryGirl.create(:ems_openstack_infra)
      end

      it "will not be visible for this record" do
        allow(@record).to receive(:supports_some_feature?).and_return(true)
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(
          view_context,
          {},
          {'record' => @record},
          {:options => {:feature => :some_feature}}
        )
        expect(button.visible?).to be_falsey
      end
    end

    context "record is not openstack infra manager" do
      before do
        @record = FactoryGirl.create(:ems_vmware)
      end

      it "will be visible for this record" do
        allow(@record).to receive(:supports_some_feature?).and_return(true)
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(
          view_context,
          {},
          {'record' => @record},
          {:options => {:feature => :some_feature}}
        )
        expect(button.visible?).to be_truthy
      end
    end
  end
end

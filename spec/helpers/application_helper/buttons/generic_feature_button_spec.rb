describe ApplicationHelper::Button::GenericFeatureButton do
  describe '#skip?' do
    describe 'the button for the instance' do
      [:pause, :shelve, :shelve_offload, :start, :stop,
       :suspend].each do |feature|
        context "that supports feature #{feature}" do
          before do
            @record = FactoryGirl.create(:vm_openstack)
            allow(@record).to receive(:is_available?).with(feature).and_return(true)
          end

          it "will not be skipped" do
             view_context = setup_view_context_with_sandbox({})
             button = described_class.new(
               view_context,
               {},
               {'record' => @record},
               {:options => {:feature => feature}}
             )
             expect(button.skip?).to be_falsey
          end
        end


        context "that does not support feature #{feature}" do
          before do
            @record = FactoryGirl.create(:vm_openstack)
            allow(@record).to receive(:is_available?).with(feature).and_return(false)
          end

          it "will be skipped" do
             view_context = setup_view_context_with_sandbox({})
             button = described_class.new(
               view_context,
               {},
               {'record' => @record},
               {:options => {:feature => feature}}
             )
             expect(button.skip?).to be_truthy
          end
        end
      end
    end

    describe 'the button for the vm' do
      [:clone].each do |feature|
        context "that supports feature #{feature}" do
          before do
            @record = FactoryGirl.create(:vm_vmware)
            allow(@record).to receive(:is_available?).with(feature).and_return(true)
          end

          it "will not be skipped" do
             view_context = setup_view_context_with_sandbox({})
             button = described_class.new(
               view_context,
               {},
               {'record' => @record},
               {:options => {:feature => feature}}
             )
             expect(button.skip?).to be_falsey
          end
        end


        context "that does not support feature #{feature}" do
          before do
            @record = FactoryGirl.create(:vm_vmware)
            allow(@record).to receive(:is_available?).with(feature).and_return(false)
          end

          it "will be skipped" do
             view_context = setup_view_context_with_sandbox({})
             button = described_class.new(
               view_context,
               {},
               {'record' => @record},
               {:options => {:feature => feature}}
             )
             expect(button.skip?).to be_truthy
          end
        end
      end
    end
  end
end

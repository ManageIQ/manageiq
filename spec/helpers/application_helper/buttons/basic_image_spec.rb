require "spec_helper"

describe ApplicationHelper::Button::BasicImage do
  describe '#skip?' do
    context "in list of archived VMs" do
      before do
        allow(ApplicationHelper).to receive(:get_record_cls).and_return(nil)
        @sb = {:trees => {:vandt_tree => {:active_node => "xx-arch"}}}
      end

      it "will be skipped" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'sb' => @sb}, {})
        expect(button.skip?).to be_truthy
      end
    end

    context "in list of orphaned VMs" do
      before do
        allow(ApplicationHelper).to receive(:get_record_cls).and_return(nil)
        @sb = {:trees => {:vandt_tree => {:active_node => "xx-arch"}}}
      end

      it "will be skipped" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'sb' => @sb}, {})
        expect(button.skip?).to be_truthy
      end
    end
  end
end

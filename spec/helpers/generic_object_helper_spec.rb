class GenericObjectHelperClass
  include GenericObjectHelper

  def initialize(toolbar_builder)
    @toolbar_builder = toolbar_builder
  end

  def _toolbar_builder
    @toolbar_builder
  end
end

describe GenericObjectHelper do
  let(:toolbar_builder) { double("ToolbarBuilder") }
  let(:subject) { GenericObjectHelperClass.new(toolbar_builder) }

  describe "#toolbar_from_hash" do
    before do
      allow(toolbar_builder).to receive(:build_by_class).with(
        ApplicationHelper::Toolbar::XHistory
      ).and_return("xhistory")

      allow(toolbar_builder).to receive(:build_by_class).with(
        ApplicationHelper::Toolbar::GenericObjectDefinition
      ).and_return("generic_object")
    end

    it "collects the built toolbars" do
      expect(subject.toolbar_from_hash).to eq(%w(xhistory generic_object))
    end
  end
end

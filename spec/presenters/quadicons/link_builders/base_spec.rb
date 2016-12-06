require "presenters/quadicons/quadicon_shared_specs"

RSpec.shared_examples :link_with_attributes do |param|
  it 'builds the link with options' do
    param ||= "quadrant_group"
    expect(link).to match(/#{param}/)
  end
end

describe Quadicons::LinkBuilders::Base, :type => :helper do
  let(:record) { FactoryGirl.create(:vm_redhat) }
  let(:kontext) { Quadicons::Context.new(helper) }
  let(:instance) { Quadicons::LinkBuilders::Base.new(record, kontext) }

  describe "determining the url" do
    subject(:url) { instance.url }

    it 'finds the url' do
      expect(url).to match(/vm_infra\/show/)
    end
  end

  describe "rendering link tag" do
    context "when called with string" do
      subject(:link) { instance.link_to("Test", :class => "quadrant_group") }

      include_examples :link_with_attributes

      it 'builds the link for simple text' do
        expect(link).to match(/Test/)
      end
    end

    context "when called with block" do
      subject(:link) do
        instance.link_to(:class => "quadrant_group") do
          content_tag(:span, "text in span")
        end
      end

      include_examples :link_with_attributes

      it 'wraps the block with a link' do
        expect(link).to include("<span>text in span</span>")
      end
    end
  end

end

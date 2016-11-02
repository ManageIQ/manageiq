describe Quadicons::ServiceQuadicon, :type => :helper do
  let(:record) { FactoryGirl.create(:service) }
  let(:kontext) { Quadicons::Context.new(helper) }
  let(:instance) { Quadicons::ServiceQuadicon.new(record, kontext) }

  describe "rendering" do
    subject(:rendered) { instance.render }

    before do
      allow(controller).to receive(:default_url_options) do
        {:controller => "service"}
      end
    end

    context "when service has a custom picture" do
      before do
        @pic = FactoryGirl.create(:picture, :extension => "svg")
        tpl = FactoryGirl.create(:service_template, :picture => @pic)
        record.service_template = tpl
      end

      it "renders quadicon with custom picture" do
        expect(rendered).to match(/pictures\/#{@pic.basename}/)
      end
    end

    context "when service has no custom picture" do
      it "renders with fallback image" do
        expect(rendered).to match(/service-[\w]*\.png/)
      end
    end

    context "for Orchestration Template Catalog Item w/o custom picture" do
      let(:record) { FactoryGirl.build(:service_template_orchestration) }

      it "renders with service template image" do
        expect(rendered).to match(/service_template-[\w]*\.png/)
      end
    end

    context "when not embedded" do
      before(:each) do
        kontext.embedded = false
      end

      it 'builds a sparkle link' do
        expect(subject).to match(/data-miq-sparkle-on/)
        expect(subject).to match(/data-miq-sparkle-off/)
      end
    end
  end
end

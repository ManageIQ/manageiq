require 'wbem'

describe Quadicons::LinkBuilders::MiqCimInstanceLinkBuilder, :type => :helper do
  let(:record) do
    obj = WBEM::CIMInstance.new("ONTAP_StorageSystem")
    obj["Name"] = "FooBar"

    FactoryGirl.create(:miq_cim_instance, :obj => obj)
  end

  let(:kontext) { Quadicons::Context.new(helper) }
  let(:instance) { Quadicons::LinkBuilders::MiqCimInstanceLinkBuilder.new(record, kontext) }

  before do
    allow(controller).to receive(:default_url_options) do
      {:controller => "provider_foreman"}
    end
  end

  describe "finding the url" do
    subject(:url) { instance.url }

    context "when not embedded" do
      context "when in explorer" do
        before do
          kontext.explorer = true
        end

        it 'links to x_show with compressed id' do
          cid = ApplicationRecord.compress_id(record.id)
          expect(url).to match(/x_show\/#{cid}/)
        end
      end

      context "when not explorer" do
        before do
          kontext.explorer = false
        end

        it 'links to the record' do
          pending "Determine if and when links for MiqCimInstances are generated outside of an explorer"
          cid = ApplicationRecord.compress_id(record.id)
          expect(url).to have_selector("a[href*='#{cid}']")
        end
      end
    end

    context "when embedded" do
      before do
        kontext.embedded = true
      end

      it 'links to nowhere' do
        expect(url).to eq('')
      end
    end
  end

  describe "html options" do
    subject(:link) { instance.link_to("Foo Bar") }

    context 'when not embedded and in explorer' do
      before do
        kontext.embedded = false
        kontext.explorer = true
      end

      it 'builds a sparkle link' do
        expect(link).to match(/data-miq-sparkle-on/)
        expect(link).to match(/data-miq-sparkle-off/)
      end
    end
  end

end

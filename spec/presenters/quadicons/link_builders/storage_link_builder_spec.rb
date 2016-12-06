require "presenters/quadicons/quadicon_shared_specs"

RSpec.shared_examples :storage_inferred_url do
  it 'links to an inferred url' do
    expect(subject).to match(/storage\/show/)
  end
end

describe Quadicons::LinkBuilders::StorageLinkBuilder, :type => :helper do
  let(:record) { FactoryGirl.create(:storage) }
  let(:kontext) { Quadicons::Context.new(helper) }
  let(:instance) { Quadicons::LinkBuilders::StorageLinkBuilder.new(record, kontext) }

  describe "finding the url" do
    subject(:url) { instance.url }

    context "when explorer" do
      before(:each) do
        kontext.explorer = true
      end

      context "and not embedded" do
        before(:each) do
          kontext.embedded = false
          allow(controller).to receive(:default_url_options) do
            {:controller => "storage"}
          end
        end

        it 'links to the record' do
          cid = ApplicationRecord.compress_id(record.id)
          expect(url).to match(/x_show\/#{cid}/)
        end
      end

      context "and embedded" do
        before(:each) do
          kontext.embedded = true
          allow(controller).to receive(:default_url_options) do
            {:controller => "storage", :action => "show"}
          end
        end

        include_examples :storage_inferred_url
      end
    end

    context "when not explorer" do
      before(:each) do
        kontext.explorer = false
      end

      context "and not embedded" do
        before(:each) do
          kontext.embedded = false
        end

        it 'links to the record' do
          cid = ApplicationRecord.compress_id(record.id)
          expect(url).to match(/storage\/show\/#{cid}/)
        end
      end

      context "and embedded" do
        before(:each) do
          kontext.embedded = true
          allow(controller).to receive(:default_url_options) do
            {:controller => "storage", :action => "show"}
          end
        end

        include_examples :storage_inferred_url
      end
    end

    describe "building the link tag" do
      subject(:link) { instance.link_to(record.name) }

      context "when explorer and not embedded" do
        before(:each) do
          kontext.explorer = true
          kontext.embedded = false
          allow(controller).to receive(:default_url_options) do
            {:controller => "storage"}
          end
        end

        include_examples :has_sparkle_link
      end
    end
  end


end

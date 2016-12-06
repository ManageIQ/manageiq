describe Quadicons::LinkBuilders::ConfigurationManagerLinkBuilder, :type => :helper do
  let(:record) { FactoryGirl.create(:configuration_manager_foreman) }
  let(:kontext) { Quadicons::Context.new(helper) }
  subject(:link) { Quadicons::LinkBuilders::ConfigurationManagerLinkBuilder.new(record, kontext) }

  context "when not embedded" do
    before do
      kontext.embedded = false

      expect(controller).to receive(:default_url_options) do
        {:controller => "provider_foreman"}
      end
    end

    it 'links to x_show with compressed id' do
      cid = ApplicationRecord.compress_id(record.id)
      expect(link.url).to match(/x_show\/#{cid}/)
    end
  end

  context "when embedded" do
    before do
      kontext.embedded = true
    end

    it 'links to nowhere' do
      expect(link.url).to eq("")
    end
  end
end

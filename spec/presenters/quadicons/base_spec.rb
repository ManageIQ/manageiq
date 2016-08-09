describe Quadicons::Base, :type => :helper do
  let(:kontext) { Quadicons::Context.new(helper) }
  let(:record) { FactoryGirl.create(:vm_vmware) }
  subject(:quadicon) { Quadicons::Base.new(record, kontext) }

  it 'renders a quadicon' do
    expect(quadicon.render).to match(/quadicon/)
  end

  it 'renders unfiltered html' do
    expect(quadicon.render).not_to match(/&lt;/)
  end

  it 'renders with a default class attribute' do
    expect(quadicon.render).to match(/quadicon/)
  end

  it 'renders with a default id attribute' do
    expect(quadicon.render).to match(/quadicon_#{record.id}/)
  end

  it 'renders with a default title attribute' do
    expect(quadicon.render).to match(/vm_#{record.id}/)
  end

  context "when context calls for single icon" do
    before(:each) do
      allow(quadicon).to receive(:render_single?).and_return(true)
    end

    it 'can render in single-mode' do
      expect(quadicon.quadrants).to eq([:type_icon])
    end
  end
end

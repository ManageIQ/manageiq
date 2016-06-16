describe Quadicons::Context, :type => :helper do
  describe "initialization" do
    it 'can be initialized with a block' do
      kontext = Quadicons::Context.new(helper) do |c|
        c.explorer = true
      end

      expect(kontext.explorer).to be(true)
      expect(kontext.in_explorer_view?).to be(true)
    end
  end

  subject(:kontext) { Quadicons::Context.new(helper) }

  it 'provides policy keys' do
    kontext.policies = { :foo => :bar }

    expect(kontext.policy_keys).to eq([:foo])
  end

  it 'delegates tag methods to template' do
    expect(kontext).to respond_to(:content_tag)
    expect(kontext).to respond_to(:image_tag)
    expect(kontext).to respond_to(:link_to)
    expect(kontext).to respond_to(:concat)
  end

  it 'determines whether to render with link' do
    kontext.listnav = false
    expect(kontext.render_link?).to be(true)
  end

  describe "fetching settings" do
    subject(:context_settings) { kontext.fetch_settings(path) }

    let(:path) { [:quadicons, :some_class_name] }

    context "when settings is nil" do
      before(:each) do
        kontext.settings = nil
      end

      it { is_expected.to be_nil }
    end

    context "when settings are present" do
      before(:each) do
        kontext.settings = { :quadicons => { :some_class_name => :foo } }
      end

      it { is_expected.to eq(:foo) }
    end
  end
end

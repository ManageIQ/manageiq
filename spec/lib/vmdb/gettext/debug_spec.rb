RSpec.describe Vmdb::Gettext::Debug do
  before { Vmdb::FastGettextHelper.register_locales }

  let(:instance) do
    Class.new do
      include Vmdb::Gettext::Debug
    end.new
  end

  let(:dl) { Vmdb::Gettext::Debug::DL }
  let(:dr) { Vmdb::Gettext::Debug::DR }
  let(:text) { "Insane text" }

  subject { instance.send(method, *args) }

  shared_examples "debug markers" do
    it "adds debug markers" do
      expect(subject).to eq("#{dl}#{text}#{dr}")
    end
  end

  describe "#_" do
    let(:args) { [text] }
    let(:method) { :_ }
    include_examples "debug markers"
  end

  describe "#n_" do
    let(:args) { [text, text, 1] }
    let(:method) { :n_ }
    include_examples "debug markers"
  end

  describe "#s_" do
    let(:args) { [text] }
    let(:method) { :s_ }
    include_examples "debug markers"
  end

  describe "#ns_" do
    let(:args) { [text, text, 1] }
    let(:method) { :ns_ }
    include_examples "debug markers"
  end
end

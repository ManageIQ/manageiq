describe ApplicationHelper::Button::InstanceRetire do
  let(:record) { FactoryGirl.create(:vm, :retired => retired) }
  subject { described_class.new(setup_view_context_with_sandbox({}), {}, {'record' => record}, {}) }

  describe '#disabled?' do
    [true, false].each do |retired|
      context "when record.retired == #{retired}" do
        let(:retired) { retired }
        it { expect(subject.disabled?).to eq(retired) }
      end
    end
  end
end

describe ApplicationHelper::Button::HistoryItem do
  describe '#skip?' do
    subject do
      sandbox = @sandbox || {
        :history     => {:testing => %w(some thing to test with)},
        :active_tree => :testing
      }

      view_context = setup_view_context_with_sandbox(sandbox)
      button = described_class.new(view_context, {}, {}, :id => @id)
      button.skip?
    end

    %w(1 2 3 4).each do |n|
      it "when with existing history_#{n}" do
        @id = "history_#{n}".to_sym
        expect(subject).to be_falsey
      end
    end

    it "when not history_1 and the tree history not exist" do
      @id = :history_10
      expect(subject).to be_truthy
    end

    it "when with history_1" do
      @id = :history_1
      expect(subject).to be_falsey
    end
  end
end


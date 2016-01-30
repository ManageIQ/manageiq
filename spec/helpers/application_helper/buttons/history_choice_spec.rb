describe ApplicationHelper::Button::HistoryChoice do
  describe '#calculate_properties' do
    subject do
      sandbox = @sandbox || {
        :history     => {:testing => %w(some thing to test with)},
        :active_tree => :testing
      }

      view_context = setup_view_context_with_sandbox(sandbox)
      button = described_class.new(view_context, {}, {}, 'id' => @id)
      button.calculate_properties
      button['enabled']
    end

    it "when x_tree_history.length > 1 then button is not disabled" do
      @id = "history_choice"
      expect(subject).not_to be false
    end

    it "when x_tree_history.length < 2 then button is disabled" do
      @sandbox = {
        :history     => {:testing => %w(something)},
        :active_tree => :testing
      }
      @id = "history_choice"
      expect(subject).to be_falsey
    end
   end
end

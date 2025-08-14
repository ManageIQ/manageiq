describe ManageIQ::Reporting::Formatter::TimelineMessage do
  context "#message_html" do
    context "for unknown column names" do
      subject { described_class.new({'column' => value}, nil, {:time_zone => 'Mexico City'}, nil).message_html('column') }

      context "with text column" do
        let(:value) { '123""45/\\' }
        it 'returns a string' do
          expect(subject).to eq '123""45/\\'
        end
      end

      context "with a time column" do
        let(:value) { Time.new(2002, 10, 31, 2, 2, 2, '+02:00') }
        it 'returns formatted time for time columns' do
          expect(subject).to eq '2002-10-30 18:02:02 CST'
        end
      end
    end
  end
end

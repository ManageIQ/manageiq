RSpec.describe MiqWidget::ContentOptionGenerator do
  let(:content_option_generator) { described_class.new }

  describe "#generate" do
    let(:group) { double("MiqGroup", :description => "description") }
    let(:users) { [user, user2, user3, user4] }
    let(:user) { double("User", :userid => 1, :get_timezone => "UTC") }
    let(:user2) { double("User", :userid => 2, :get_timezone => "UTC") }
    let(:user3) { double("User", :userid => 3, :get_timezone => "PST") }
    let(:user4) { 4 }

    before do
      allow(group).to receive(:kind_of?).with(MiqGroup).and_return(kind_of_miq_group)
    end

    shared_examples_for "WidgetContentOptionGenerator#generate that returns User related options" do
      it "returns an array of User, userids, and nil" do
        expect(content_option_generator.generate(group, users)).to eq(["User", group.description, [1, 2, 3, 4], nil])
      end
    end

    context "when the group is an MiqGroup" do
      let(:kind_of_miq_group) { true }

      before do
        allow(group).to receive(:self_service?).and_return(self_service)
      end

      context "when the group is self service" do
        let(:self_service) { true }

        it_behaves_like "WidgetContentOptionGenerator#generate that returns User related options"
      end

      context "when the group is not self service" do
        let(:self_service) { false }

        it "returns an array of MiqGroup, description, timezones" do
          expect(content_option_generator.generate(group, users)).to eq(["MiqGroup", "description", nil, ["PST", "UTC"]])
        end
      end
    end

    context "when the group is not an MiqGroup" do
      let(:kind_of_miq_group) { false }

      it_behaves_like "WidgetContentOptionGenerator#generate that returns User related options"
    end
  end
end

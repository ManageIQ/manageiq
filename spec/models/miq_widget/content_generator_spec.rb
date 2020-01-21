RSpec.describe MiqWidget::ContentGenerator do
  let(:content_generator) { described_class.new }

  describe "#generate" do
    let(:widget) { instance_double("MiqWidget", :id => 123, :title => "title", :log_prefix => "") }
    let(:records) { instance_double(ActiveRecord::Relation) }

    context "when the class is MiqGroup" do
      let(:klass) { "MiqGroup" }
      let(:userids) { [1, 2] }
      let(:timezones) { ["PST", "UTC"] }
      let(:user1) { double("User", :get_timezone => "PST") }
      let(:user2) { double("User", :get_timezone => "UTC") }
      let(:group_description) { "description" }

      before do
        allow(User).to receive(:where).with(:userid => 1).and_return([user1])
        allow(User).to receive(:where).with(:userid => 2).and_return([user2])
        allow(MiqGroup).to receive(:in_my_region).and_return(records)
        allow(records).to receive(:find_by).with(:description => "description").and_return(group)
      end

      context "when the group exists" do
        let(:group) { double("MiqGroup") }

        context "when the resulting length is equal to the expected count" do
          before do
            allow(widget).to receive(:generate_one_content_for_group).with(group, "PST").and_return(4)
            allow(widget).to receive(:generate_one_content_for_group).with(group, "UTC").and_return(5)
          end

          it "returns the result" do
            expect(MiqGroup).to receive(:in_my_region)
            expect(content_generator.generate(widget, klass, group_description, nil, timezones)).to eq([4, 5])
          end
        end

        context "when the resulting length is not equal to the expected count" do
          before do
            allow(widget).to receive(:generate_one_content_for_group).with(group, "PST").and_return(4)
            allow(widget).to receive(:generate_one_content_for_group).with(group, "UTC").and_return(nil)
          end

          it "raises an MiqException::Error" do
            expected_error_message = "Expected 2 contents, received 1 contents for Group: description"
            expect { content_generator.generate(widget, klass, group_description, nil, timezones) }.to raise_error(MiqException::Error, expected_error_message)
          end
        end
      end

      context "when the group does not exist" do
        let(:group) { nil }

        it "raises an MiqException::Error" do
          expected_error_message = "MiqGroup description was not found"
          expect { content_generator.generate(widget, klass, group_description, nil, timezones) }.to raise_error(MiqException::Error, expected_error_message)
        end
      end
    end

    context "when the class is User" do
      let(:klass) { "User" }
      let(:userids) { [1, 2] }
      let(:group_description) { "EvmGroup-administrator" }
      let(:group) { double("MiqGroup") }

      before do
        allow(MiqGroup).to receive(:in_my_region).and_return(records)
        allow(records).to receive(:find_by).with(:description => "EvmGroup-administrator").and_return(group)
      end

      context "when the resulting length is equal to the expected count" do
        before do
          allow(widget).to receive(:generate_one_content_for_user).with(group, 1).and_return(4)
          allow(widget).to receive(:generate_one_content_for_user).with(group, 2).and_return(5)
        end

        it "returns the result" do
          expect(widget).to receive(:delete_legacy_contents_for_group)
          expect(content_generator.generate(widget, klass, group_description, userids)).to eq([4, 5])
        end
      end

      context "when the resulting length is not equal to the expected count" do
        before do
          allow(widget).to receive(:generate_one_content_for_user).with(group, 1).and_return(4)
          allow(widget).to receive(:generate_one_content_for_user).with(group, 2).and_return(nil)
        end

        it "raises an MiqException::Error" do
          expected_error_message = "Expected 2 contents, received 1 contents for [1, 2]"
          expect(widget).to receive(:delete_legacy_contents_for_group)
          expect { content_generator.generate(widget, klass, group_description, userids) }.to raise_error(MiqException::Error, expected_error_message)
        end
      end
    end

    context "when the class is something else" do
      let(:klass) { "Potato" }
      let(:userids) { [] }
      let(:group_description) { "EvmGroup-administrator" }

      it "raises" do
        expect { content_generator.generate(widget, klass, group_description, userids) }.to raise_error(StandardError, "Unsupported: Potato")
      end
    end
  end
end

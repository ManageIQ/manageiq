require "spec_helper"

describe MiqWidget::ContentGenerator do
  let(:content_generator) { described_class.new }

  describe "#generate" do
    let(:widget) { active_record_instance_double("MiqWidget", :id => 123, :title => "title") }

    context "when the class is MiqGroup" do
      let(:klass) { "MiqGroup" }
      let(:userids) { [1, 2] }
      let(:timezones) { ["PST", "UTC"] }
      let(:user1) { active_record_instance_double("User", :get_timezone => "PST") }
      let(:user2) { active_record_instance_double("User", :get_timezone => "UTC") }
      let(:group_description) { "description" }

      before do
        User.stub(:where).with(:userid => 1).and_return([user1])
        User.stub(:where).with(:userid => 2).and_return([user2])
        MiqGroup.stub(:where).with(:description => "description").and_return([group])
      end

      context "when the group exists" do
        let(:group) { active_record_instance_double("MiqGroup") }

        context "when the resulting length is equal to the expected count" do
          before do
            widget.stub(:generate_one_content_for_group).with(group, "PST").and_return(4)
            widget.stub(:generate_one_content_for_group).with(group, "UTC").and_return(5)
          end

          it "returns the result" do
            content_generator.generate(widget, klass, group_description, nil, timezones).should == [4, 5]
          end
        end

        context "when the resulting length is not equal to the expected count" do
          before do
            widget.stub(:generate_one_content_for_group).with(group, "PST").and_return(4)
            widget.stub(:generate_one_content_for_group).with(group, "UTC").and_return(nil)
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
      let(:group) { active_record_instance_double("MiqGroup") }

      before { MiqGroup.stub(:where).with(:description => "EvmGroup-administrator").and_return([group]) }

      context "when the resulting length is equal to the expected count" do
        before do
          widget.stub(:generate_one_content_for_user).with(group, 1).and_return(4)
          widget.stub(:generate_one_content_for_user).with(group, 2).and_return(5)
        end

        it "returns the result" do
          widget.should_receive(:delete_legacy_contents_for_group)
          content_generator.generate(widget, klass, group_description, userids).should == [4, 5]
        end
      end

      context "when the resulting length is not equal to the expected count" do
        before do
          widget.stub(:generate_one_content_for_user).with(group, 1).and_return(4)
          widget.stub(:generate_one_content_for_user).with(group, 2).and_return(nil)
        end

        it "raises an MiqException::Error" do
          expected_error_message = "Expected 2 contents, received 1 contents for [1, 2]"
          widget.should_receive(:delete_legacy_contents_for_group)
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

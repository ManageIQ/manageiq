require "spec_helper"

describe PrivilegeCheckerService do
  let(:vmdb_config) { {:session => {:timeout => 3600}} }
  let(:privilege_checker) { described_class.new(vmdb_config) }

  describe "#valid_session?" do
    shared_examples_for "PrivilegeCheckerService#valid_session? that returns false" do
      it "returns false" do
        privilege_checker.valid_session?(session, user).should be_false
      end
    end

    let(:session) do
      {
        :last_trans_time => last_trans_time
      }
    end

    context "when the user is signed out" do
      let(:user) { nil }
      let(:last_trans_time) { nil }

      it_behaves_like "PrivilegeCheckerService#valid_session? that returns false"
    end

    context "when the user is signed in" do
      let(:user) { FactoryGirl.create(:user) }

      context "when the session is timed out" do
        let(:last_trans_time) { 2.hours.ago }

        it_behaves_like "PrivilegeCheckerService#valid_session? that returns false"
      end

      context "when the session has not timed out" do
        let(:last_trans_time) { Time.current }
        let(:server) { active_record_instance_double("MiqServer", :logon_status => logon_status) }

        before do
          MiqServer.stub(:my_server).with(true).and_return(server)
        end

        context "when the server is not ready" do
          let(:logon_status) { :not_ready }

          it_behaves_like "PrivilegeCheckerService#valid_session? that returns false"
        end

        context "when the server is ready" do
          let(:logon_status) { :ready }

          it "returns true" do
            privilege_checker.valid_session?(session, user).should be_true
          end
        end
      end
    end
  end

  describe "#user_session_timed_out?" do
    let(:session) do
      {
        :last_trans_time => last_trans_time
      }
    end

    context "when a user exists" do
      let(:user) { FactoryGirl.create(:user) }

      context "when the session is timed out" do
        let(:last_trans_time) { 2.hours.ago }

        it "returns true" do
          privilege_checker.user_session_timed_out?(session, user).should be_true
        end
      end

      context "when the session has not timed out" do
        let(:last_trans_time) { Time.current }

        it "returns false" do
          privilege_checker.user_session_timed_out?(session, user).should be_false
        end
      end
    end

    context "when a user does not exist" do
      let(:user) { nil }
      let(:last_trans_time) { nil }

      it "returns false" do
        privilege_checker.user_session_timed_out?(session, user).should be_false
      end
    end
  end
end

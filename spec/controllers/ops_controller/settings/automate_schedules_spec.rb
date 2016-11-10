describe OpsController do
  let(:params) { {} }
  let(:session) { {} }
  let(:zone) { double("Zone", :name => "foo") }
  let(:server) { double("MiqServer", :logon_status => :ready, :id => 1, :my_zone => zone) }
  let(:schedule) { FactoryGirl.create(:miq_automate_schedule) }
  let(:schedule_new) { MiqSchedule.new }
  let(:user) { stub_user(:features => :all) }

  include_context "valid session"

  before do
    allow(MiqServer).to receive(:my_server).and_return(server)
    allow(server).to receive(:zone_id).and_return(1)
    stub_user(:features => :all)
  end

  describe "#schedule_set_record_vars" do
    context "set object_request as parameters[:request]" do
      it "has a nil request for a new automate schedule" do
        params[:id] = "new"
        post :automate_schedules_set_vars, :params => params, :session => session

        json = JSON.parse(response.body)
        expect(json["object_request"]).to eq ""
      end

      it "has the correct request when looking up an existing automation schedule" do
        params[:id] = schedule.id
        post :automate_schedules_set_vars, :params => params, :session => session

        json = JSON.parse(response.body)
        expect(schedule.filter[:parameters]['request']).to eq "test_request"
        expect(schedule.filter[:parameters]['key1']).to eq 'value1'
        expect(json["object_request"]).to eq "test_request"
      end
    end
  end

  describe "#fetch_automate_request_vars" do
    include OpsController::Settings::AutomateSchedules
    let(:ops) { OpsController.new }

    before do
      session = instance_double('ApplicationController', :session => {:userid => user.userid})
      ops.instance_variable_set(:@current_user, user)
      ops.instance_variable_set(:@_request, session)
    end

    it "transposes filter[:parameters][:request] to :object_request" do
      automate_request = ops.fetch_automate_request_vars(schedule)
      expect(schedule.filter[:parameters][:request]).to eq "test_request"
      expect(automate_request[:object_request]).to eq "test_request"
    end

    it "instantiates an empty hash for a new schedule" do
      automate_request = ops.fetch_automate_request_vars(schedule_new)
      expect(schedule_new.filter).to be_nil
      expect(automate_request[:object_request]).to eq ""
    end
  end
end

require 'spec_helper'

describe ReportController do
  render_views
  before :each do
    set_user_privileges
    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone
  end

  context 'Reports #tree_select' do
    it 'renders list of Reports in Reports - Custom tree' do
      4.times { FactoryGirl.create(:miq_report) }

      session[:settings] = {}
      seed_session_trees('report', :reports_tree)

      post :tree_select, :id => 'reports_xx-0', :format => :js

      response.should render_template('report/_report_list')
      expect(response.status).to eq(200)
    end
  end
end

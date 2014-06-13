require 'spec_helper'
require 'routing/shared_examples'

describe 'routes for MiqPolicyController' do
  let(:controller_name) { 'miq_policy' }

  it_behaves_like 'A controller that has advanced search routes'
  it_behaves_like 'A controller that has explorer routes'

  describe '#action_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/action_edit")).to route_to("#{controller_name}#action_edit")
    end
  end

  describe '#action_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/action_field_changed")).to route_to("#{controller_name}#action_field_changed")
    end
  end

  describe '#action_get_all' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/action_get_all")).to route_to("#{controller_name}#action_get_all")
    end
  end

  describe '#action_tag_pressed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/action_tag_pressed")).to route_to("#{controller_name}#action_tag_pressed")
    end
  end

  describe '#alert_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/alert_edit")).to route_to("#{controller_name}#alert_edit")
    end
  end

  describe '#alert_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/alert_field_changed")).to route_to("#{controller_name}#alert_field_changed")
    end
  end

  describe '#alert_get_all' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/alert_get_all")).to route_to("#{controller_name}#alert_get_all")
    end
  end

  describe '#alert_profile_assign' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/alert_profile_assign")).to route_to("#{controller_name}#alert_profile_assign")
    end
  end

  describe '#alert_profile_assign_changed' do
    it 'routes with POST' do
      expect(
        post("/#{controller_name}/alert_profile_assign_changed")
      ).to route_to("#{controller_name}#alert_profile_assign_changed")
    end
  end

  describe '#alert_profile_delete' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/alert_profile_delete")).to route_to("#{controller_name}#alert_profile_delete")
    end
  end

  describe '#alert_profile_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/alert_profile_edit")).to route_to("#{controller_name}#alert_profile_edit")
    end
  end

  describe '#alert_profile_field_changed' do
    it 'routes with POST' do
      expect(
        post("/#{controller_name}/alert_profile_field_changed")
      ).to route_to("#{controller_name}#alert_profile_field_changed")
    end
  end

  describe '#button' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/button")).to route_to("#{controller_name}#button")
    end
  end

  describe '#condition_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/condition_edit")).to route_to("#{controller_name}#condition_edit")
    end
  end

  describe '#condition_field_changed' do
    it 'routes with POST' do
      expect(
        post("/#{controller_name}/condition_field_changed")
      ).to route_to("#{controller_name}#condition_field_changed")
    end
  end

  describe '#event_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/event_edit")).to route_to("#{controller_name}#event_edit")
    end
  end

  describe '#export' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/export")).to route_to("#{controller_name}#export")
    end
  end

  describe '#export_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/export_field_changed")).to route_to("#{controller_name}#export_field_changed")
    end
  end

  describe '#fetch_log' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/fetch_log")).to route_to("#{controller_name}#fetch_log")
    end
  end

  describe '#fetch_yaml' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/fetch_yaml")).to route_to("#{controller_name}#fetch_yaml")
    end
  end

  describe '#get_json' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/get_json")).to route_to("#{controller_name}#get_json")
    end
  end

  describe '#import' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/import")).to route_to("#{controller_name}#import")
    end

    it 'routes with POST' do
      expect(post("/#{controller_name}/import")).to route_to("#{controller_name}#import")
    end
  end

  describe '#index' do
    it 'routes with GET' do
      expect(get("/#{controller_name}")).to route_to("#{controller_name}#index")
    end
  end

  describe '#log' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/log")).to route_to("#{controller_name}#log")
    end
  end

  describe '#policy_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/policy_edit")).to route_to("#{controller_name}#policy_edit")
    end
  end

  describe '#policy_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/policy_field_changed")).to route_to("#{controller_name}#policy_field_changed")
    end
  end

  describe '#policy_get_all' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/policy_get_all")).to route_to("#{controller_name}#policy_get_all")
    end
  end

  describe '#profile_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/profile_edit")).to route_to("#{controller_name}#profile_edit")
    end
  end

  describe '#profile_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/profile_edit")).to route_to("#{controller_name}#profile_edit")
    end
  end

  describe '#reload' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/reload")).to route_to("#{controller_name}#reload")
    end
  end

  describe '#rsop' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/rsop")).to route_to("#{controller_name}#rsop")
    end

    it 'routes with POST' do
      expect(post("/#{controller_name}/rsop")).to route_to("#{controller_name}#rsop")
    end
  end

  describe '#rsop_option_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rsop_option_changed")).to route_to("#{controller_name}#rsop_option_changed")
    end
  end

  describe '#rsop_toggle' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rsop_toggle")).to route_to("#{controller_name}#rsop_toggle")
    end
  end

  describe '#rsop_show_options' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rsop_show_options")).to route_to("#{controller_name}#rsop_show_options")
    end
  end

  describe '#upload' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/upload")).to route_to("#{controller_name}#upload")
    end
  end

  describe '#wait_for_task' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/wait_for_task")).to route_to("#{controller_name}#wait_for_task")
    end
  end

  describe '#x_button' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/x_button")).to route_to("#{controller_name}#x_button")
    end
  end

  describe '#x_history' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/x_history")).to route_to("#{controller_name}#x_history")
    end
  end

  describe '#x_show' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/x_show")).to route_to("#{controller_name}#x_show")
    end
  end
end

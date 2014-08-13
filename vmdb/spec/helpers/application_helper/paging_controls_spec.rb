require "spec_helper"

describe ApplicationHelper::PagingControls do

  describe "#paging_controls_url" do

    before do
      helper.request.path_parameters["controller"] = "vm"
    end

    it "with an id" do
      action_url = "show_list/1"
      url = helper.paging_controls_url(action_url)
      expect(url).to eq("/vm/show_list/1")
    end

    it "with no extra URL parms" do
      action_url = "show_list"
      url = helper.paging_controls_url(action_url)
      expect(url).to eq("/vm/show_list")
    end

    it "with extra URL parms" do
      action_url = "show_list"
      url = helper.paging_controls_url(action_url, :page => "1")
      expect(url).to eq("/vm/show_list?page=1")
    end

    it "with extra URL parms and params[:sb_controller] set" do
      action_url = "show_list"
      helper.params[:sb_controller] = "ems_cluster"
      url = helper.paging_controls_url(action_url, :page => "1")
      expect(url).to eq("/vm/show_list?page=1&sb_controller=ems_cluster")
    end

  end
end

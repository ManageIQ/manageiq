require "spec_helper"
require "routing/shared_examples"

describe MiqAeCustomizationController do
  let(:controller_name) { 'miq_ae_customization' }

  it_behaves_like "A controller that has column width routes"

  describe "#ab_group_reorder" do
    it "routes with POST" do
      expect(post("/#{controller_name}/ab_group_reorder")).to route_to("#{controller_name}#ab_group_reorder")
    end
  end

  describe "#ae_tree_select" do
    it "routes with POST" do
      expect(post("/#{controller_name}/ae_tree_select")).to route_to("#{controller_name}#ae_tree_select")
    end
  end

  describe "#ae_tree_select_toggle" do
    it "routes with POST" do
      expect(post("/#{controller_name}/ae_tree_select_toggle")).to route_to(
        "#{controller_name}#ae_tree_select_toggle"
      )
    end
  end

  describe "#accordion_select" do
    it "routes with POST" do
      expect(post("/#{controller_name}/accordion_select")).to route_to("#{controller_name}#accordion_select")
    end
  end

  describe "#automate_button_field_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/automate_button_field_changed")).to route_to(
        "#{controller_name}#automate_button_field_changed"
      )
    end
  end

  describe "#button_create" do
    it "routes with POST" do
      expect(post("/#{controller_name}/button_create")).to route_to("#{controller_name}#button_create")
    end
  end

  describe "#button_update" do
    it "routes with POST" do
      expect(post("/#{controller_name}/button_update")).to route_to("#{controller_name}#button_update")
    end
  end

  describe "#cancel_import" do
    it "routes with POST" do
      expect(post("/#{controller_name}/cancel_import")).to route_to("#{controller_name}#cancel_import")
    end
  end

  describe "#change_tab" do
    it "routes with POST" do
      expect(post("/#{controller_name}/change_tab")).to route_to("#{controller_name}#change_tab")
    end
  end

  describe "#dialog_edit" do
    it "routes with POST" do
      expect(post("/#{controller_name}/dialog_edit")).to route_to("#{controller_name}#dialog_edit")
    end
  end

  describe "#dialog_form_field_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/dialog_form_field_changed")).to route_to(
        "#{controller_name}#dialog_form_field_changed"
      )
    end
  end

  describe "#dialog_res_remove" do
    it "routes with POST" do
      expect(post("/#{controller_name}/dialog_res_remove")).to route_to("#{controller_name}#dialog_res_remove")
    end
  end

  describe "#dialog_res_reorder" do
    it "routes with GET" do
      expect(get("/#{controller_name}/dialog_res_reorder")).to route_to("#{controller_name}#dialog_res_reorder")
    end
  end

  describe "#explorer" do
    it "routes with GET" do
      expect(get("/#{controller_name}/explorer")).to route_to("#{controller_name}#explorer")
    end

    it "routes with POST" do
      expect(post("/#{controller_name}/explorer")).to route_to("#{controller_name}#explorer")
    end
  end

  describe "#export_service_dialogs" do
    it "routes with GET" do
      expect(get("/#{controller_name}/export_service_dialogs")).to route_to(
        "#{controller_name}#export_service_dialogs"
      )
    end
  end

  describe "#field_value_accept" do
    it "routes with POST" do
      expect(post("/#{controller_name}/field_value_accept")).to route_to("#{controller_name}#field_value_accept")
    end
  end

  describe "#field_value_delete" do
    it "routes with POST" do
      expect(post("/#{controller_name}/field_value_delete")).to route_to("#{controller_name}#field_value_delete")
    end
  end

  describe "#field_value_select" do
    it "routes with POST" do
      expect(post("/#{controller_name}/field_value_select")).to route_to("#{controller_name}#field_value_select")
    end
  end

  describe "#group_create" do
    it "routes with POST" do
      expect(post("/#{controller_name}/group_create")).to route_to("#{controller_name}#group_create")
    end
  end

  describe "#group_form_field_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/group_form_field_changed")).to route_to(
        "#{controller_name}#group_form_field_changed"
      )
    end
  end

  describe "#group_reorder_field_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/group_reorder_field_changed")).to route_to(
        "#{controller_name}#group_reorder_field_changed"
      )
    end
  end

  describe "#group_update" do
    it "routes with POST" do
      expect(post("/#{controller_name}/group_update")).to route_to("#{controller_name}#group_update")
    end
  end

  describe "#import_service_dialogs" do
    it "routes with POST" do
      expect(post("/#{controller_name}/import_service_dialogs")).to route_to(
        "#{controller_name}#import_service_dialogs"
      )
    end
  end

  describe "#old_dialogs_form_field_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/old_dialogs_form_field_changed")).to route_to(
        "#{controller_name}#old_dialogs_form_field_changed"
      )
    end
  end

  describe "#old_dialogs_list" do
    it "routes with POST" do
      expect(post("/#{controller_name}/old_dialogs_list")).to route_to("#{controller_name}#old_dialogs_list")
    end
  end

  describe "#old_dialogs_update" do
    it "routes with POST" do
      expect(post("/#{controller_name}/old_dialogs_update")).to route_to("#{controller_name}#old_dialogs_update")
    end
  end

  describe "#reload" do
    it "routes with POST" do
      expect(post("/#{controller_name}/reload")).to route_to("#{controller_name}#reload")
    end
  end

  describe "#resolve" do
    it "routes with POST" do
      expect(post("/#{controller_name}/resolve")).to route_to("#{controller_name}#resolve")
    end
  end

  describe "#review_import" do
    it "routes with GET" do
      expect(get("/#{controller_name}/review_import")).to route_to("#{controller_name}#review_import")
    end
  end

  describe "#service_dialog_json" do
    it "routes with GET" do
      expect(get("/#{controller_name}/service_dialog_json")).to route_to("#{controller_name}#service_dialog_json")
    end
  end

  describe "#tree_autoload_dynatree" do
    it "routes with POST" do
      expect(post("/#{controller_name}/tree_autoload_dynatree")).to route_to(
        "#{controller_name}#tree_autoload_dynatree"
      )
    end
  end

  describe "#tree_select" do
    it "routes with POST" do
      expect(post("/#{controller_name}/tree_select")).to route_to("#{controller_name}#tree_select")
    end
  end

  describe "#upload_import_file" do
    it "routes with POST" do
      expect(post("/#{controller_name}/upload_import_file")).to route_to("#{controller_name}#upload_import_file")
    end
  end

  describe "#x_button" do
    it "routes with POST" do
      expect(post("/#{controller_name}/x_button")).to route_to("#{controller_name}#x_button")
    end
  end

  describe "#x_history" do
    it "routes with POST" do
      expect(post("/#{controller_name}/x_history")).to route_to("#{controller_name}#x_history")
    end
  end

  describe "#x_settings_changed" do
    it "routes with POST" do
      expect(post("/#{controller_name}/x_settings_changed")).to route_to("#{controller_name}#x_settings_changed")
    end
  end

  describe "#x_show" do
    it "routes with POST" do
      expect(post("/#{controller_name}/x_show")).to route_to("#{controller_name}#x_show")
    end
  end
end

shared_examples_for 'A controller that has vm_common routes' do
  describe '#advanced_settings' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/advanced_settings")).to route_to("#{controller_name}#advanced_settings")
    end
  end

  describe '#button' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/button")).to route_to("#{controller_name}#button")
    end
  end

  describe '#drift_all' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/drift_all")).to route_to("#{controller_name}#drift_all")
    end
  end

  describe '#drift_compress' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/drift_compress")).to route_to("#{controller_name}#drift_compress")
    end
  end

  describe '#drift_differences' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/drift_differences")).to route_to("#{controller_name}#drift_differences")
    end
  end

  describe '#drift_history' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/drift_history")).to route_to("#{controller_name}#drift_history")
    end
  end

  describe '#drift_mode' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/drift_mode")).to route_to("#{controller_name}#drift_mode")
    end
  end

  describe '#drift_same' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/drift_same")).to route_to("#{controller_name}#drift_same")
    end
  end

  describe '#drift_to_csv' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/drift_to_csv")).to route_to("#{controller_name}#drift_to_csv")
    end
  end

  describe '#drift_to_pdf' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/drift_to_txt")).to route_to("#{controller_name}#drift_to_txt")
    end
  end

  describe '#drift_to_txt' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/drift_to_txt")).to route_to("#{controller_name}#drift_to_txt")
    end
  end

  describe '#event_logs' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/event_logs")).to route_to("#{controller_name}#event_logs")
    end
  end

  describe '#edit_vm' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/edit_vm")).to route_to("#{controller_name}#edit_vm")
    end
  end

  describe '#evm_relationship_field_changed' do
    it 'routes with POST' do
      expect(
          post("/#{controller_name}/evm_relationship_field_changed")
      ).to route_to("#{controller_name}#evm_relationship_field_changed")
    end
  end

  describe '#evm_relationship_update' do
    it 'routes with POST' do
      expect(
          post("/#{controller_name}/evm_relationship_update")
      ).to route_to("#{controller_name}#evm_relationship_update")
    end
  end

  describe '#explorer' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/explorer")).to route_to("#{controller_name}#explorer")
    end
  end

  describe '#filesystems' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/filesystems")).to route_to("#{controller_name}#filesystems")
    end
  end

  describe '#filesystem_drivers' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/filesystem_drivers")).to route_to("#{controller_name}#filesystem_drivers")
    end
  end

  describe '#form_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/form_field_changed")).to route_to("#{controller_name}#form_field_changed")
    end
  end

  describe '#groups' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/groups")).to route_to("#{controller_name}#groups")
    end
  end

  describe '#guest_applications' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/guest_applications")).to route_to("#{controller_name}#guest_applications")
    end
  end

  describe '#kernel_drivers' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/kernel_drivers")).to route_to("#{controller_name}#kernel_drivers")
    end
  end

  describe '#linux_initprocesses' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/linux_initprocesses")).to route_to("#{controller_name}#linux_initprocesses")
    end
  end

  describe '#ownership_field_changed' do
    it 'routes with POST' do
      expect(
          post("/#{controller_name}/ownership_field_changed")
      ).to route_to("#{controller_name}#ownership_field_changed")
    end
  end

  describe '#ownership_update' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ownership_update")).to route_to("#{controller_name}#ownership_update")
    end
  end

  describe '#patches' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/patches")).to route_to("#{controller_name}#patches")
    end
  end

  describe '#policies' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/policies")).to route_to("#{controller_name}#policies")
    end
  end

  describe '#policy_options' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/policy_options")).to route_to("#{controller_name}#policy_options")
    end
  end

  describe '#policy_show_options' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/policy_show_options")).to route_to("#{controller_name}#policy_show_options")
    end
  end

  describe '#policy_sim' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/policy_sim")).to route_to("#{controller_name}#policy_sim")
    end
  end

  describe '#policy_sim_add' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/policy_sim_add")).to route_to("#{controller_name}#policy_sim_add")
    end
  end

  describe '#policy_sim_remove' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/policy_sim_remove")).to route_to("#{controller_name}#policy_sim_remove")
    end
  end

  describe '#processes' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/processes")).to route_to("#{controller_name}#processes")
    end
  end

  describe '#prov_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/prov_edit")).to route_to("#{controller_name}#prov_edit")
    end
  end

  describe '#prov_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/prov_field_changed")).to route_to("#{controller_name}#prov_field_changed")
    end
  end

  describe '#registry_items' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/registry_items")).to route_to("#{controller_name}#registry_items")
    end
  end

  describe '#reload' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/reload")).to route_to("#{controller_name}#reload")
    end
  end

  describe '#retire' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/retire")).to route_to("#{controller_name}#retire")
    end
  end

  describe '#retire_date_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/retire_date_changed")).to route_to("#{controller_name}#retire_date_changed")
    end
  end

  describe '#scan_histories' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/scan_histories")).to route_to("#{controller_name}#scan_histories")
    end
  end

  describe '#sections_field_changed' do
    it 'routes with POST' do
      expect(
          post("/#{controller_name}/sections_field_changed")
      ).to route_to("#{controller_name}#sections_field_changed")
    end
  end

  describe '#security_groups' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/security_groups")).to route_to("#{controller_name}#security_groups")
    end
  end

  describe '#show' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/show")).to route_to("#{controller_name}#show")
    end

    it 'routes with POST' do
      expect(post("/#{controller_name}/show")).to route_to("#{controller_name}#show")
    end
  end

  describe '#squash_toggle' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/squash_toggle")).to route_to("#{controller_name}#squash_toggle")
    end
  end

  describe '#users' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/users")).to route_to("#{controller_name}#users")
    end
  end

  describe '#win32_services' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/win32_services")).to route_to("#{controller_name}#win32_services")
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

  describe '#x_search_by_name' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/x_search_by_name")).to route_to("#{controller_name}#x_search_by_name")
    end
  end

  describe '#x_settings_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/x_settings_changed")).to route_to("#{controller_name}#x_settings_changed")
    end
  end

  describe '#x_show' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/x_show")).to route_to("#{controller_name}#x_show")
    end
  end
end

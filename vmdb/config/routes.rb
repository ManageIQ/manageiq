Vmdb::Application.routes.draw do

  CONTROLLER_ACTIONS = {
    :agent => {
      :get  => %w(get),
      :post => %w(log)
    },

    :alert                   => {
      :get  => %w(
        index
        rss
        show_list
      ),
      :post => %w(
        role_selected
        start_rss
      ),
    },

    :availability_zone       => {
      :get  => %w(
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        download_data
        index
        perf_top_chart
        show
        show_list
        tagging_edit
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        exp_button
        exp_changed
        exp_token_pressed
        panel_control
        perf_chart_chooser
        perf_top_chart
        quick_search
        save_col_widths
        sections_field_changed
        show
        show_list
        tagging_edit
        tag_edit_form_field_changed
        tl_chooser
        wait_for_task
      )
    },

    :catalog                 => {
      :get  => %w(
        download_data
        explorer
        show
      ),
      :post => %w(
        accordion_select
        ae_tree_select
        ae_tree_select_discard
        ae_tree_select_toggle
        atomic_form_field_changed
        atomic_st_edit
        automate_button_field_changed
        button_create
        button_update
        dialog_field_changed
        dialog_form_button_pressed
        dynamic_list_refresh
        explorer
        get_ae_tree_edit_key
        group_create
        group_form_field_changed
        group_update
        identify_catalog
        process_sts
        prov_field_changed
        reload
        resolve
        resource_delete
        save_col_widths
        servicetemplate_edit
        sort_ds_grid
        sort_host_grid
        sort_iso_img_grid
        sort_pxe_img_grid
        sort_vm_grid
        st_catalog_edit
        st_catalog_form_field_changed
        st_delete
        st_edit
        st_form_field_changed
        st_tags_edit
        st_upload_image
        svc_catalog_provision
        tag_edit_form_field_changed
        tree_autoload_dynatree
        tree_select
        x_button
        x_history
        x_settings_changed
        x_show
      ),
    },

    :chargeback              => {
      :get  => %w(
        explorer
        index
        render_csv
        render_pdf
        render_txt
        report_only
      ),
      :post => %w(
        accordion_select
        explorer
        cb_assign_field_changed
        cb_assign_update
        cb_rate_edit
        cb_rate_form_field_changed
        cb_rate_show
        cb_rates_delete
        cb_rates_list
        tree_autoload_dynatree
        tree_select
        x_button
      )
    },

    :cloud_tenant            => {
      :get => %w(
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        download_data
        edit
        index
        protect
        show
        show_list
        tagging_edit
      ),
      :post => %w(
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        protect
        sections_field_changed
        show
        show_list
        tagging_edit
        tag_edit_form_field_changed
        update
        panel_control
      )
    },

    :configuration => {
      # TODO: routes for new/edit/copy buttons need to be revisited
      # TODO: so they can be changed to send up POST request instead of GET
      :get => %w(
        change_tab
        index
        show
        timeprofile_copy
        timeprofile_edit
        timeprofile_new
      ),
      :post => %w(
        button
        filters_field_changed
        form_field_changed
        theme_changed
        timeprofile_create
        timeprofile_delete
        timeprofile_field_changed
        timeprofile_update
        update
        view_selected
      )
    },

    :dashboard => {
      :get => %w(
        change_tab
        index
        login
        logout
        maintab
        render_csv
        render_pdf
        render_txt
        render_chart
        report_only
        show
        timeline
        widget_to_pdf
      ),
      :post => %w(
        kerberos_authenticate
        authenticate
        change_group
        csp_report
        getTLdata
        login_retry
        panel_control
        reset_widgets
        show_timeline
        tl_generate
        wait_for_task
        widget_add
        widget_close
        widget_dd_done
        widget_toggle_minmax
        widget_zoom
        window_sizes
      )
    },

    :ems_cloud => {
      :get => %w(
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        discover
        download_data
        edit
        index
        new
        protect
        show
        show_list
        tagging_edit
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        create
        discover
        discover_field_changed
        dynamic_list_refresh
        exp_button
        exp_changed
        exp_token_pressed
        form_field_changed
        panel_control
        protect
        quick_search
        save_col_widths
        sections_field_changed
        show
        show_list
        tag_edit_form_field_changed
        tagging_edit
        tl_chooser
        update
        wait_for_task
      )
    },

    :ems_cluster => {
      :get => %w(
        columns_json
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        download_data
        drift
        drift_history
        drift_to_csv
        drift_to_pdf
        drift_to_txt
        index
        perf_top_chart
        protect
        rows_json
        show
        show_list
        tagging_edit
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        drift_all
        drift_compress
        drift_differences
        drift_history
        drift_mode
        drift_same
        dynamic_list_refresh
        exp_button
        exp_changed
        exp_token_pressed
        listnav_search_selected
        panel_control
        perf_chart_chooser
        perf_top_chart
        protect
        quick_search
        save_col_widths
        save_default_search
        sections_field_changed
        show
        show_list
        tag_edit_form_field_changed
        tagging_edit
        tl_chooser
        wait_for_task
      )
    },

    :ems_infra => {
      :get => %w(
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        discover
        download_data
        edit
        index
        new
        protect
        show
        show_list
        tagging_edit
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        create
        discover
        discover_field_changed
        exp_button
        exp_changed
        exp_token_pressed
        form_field_changed
        panel_control
        protect
        quick_search
        save_col_widths
        sections_field_changed
        show
        show_list
        tag_edit_form_field_changed
        tagging_edit
        tl_chooser
        tree_autoload_dynatree
        tree_autoload_quads
        update
        wait_for_task
      )
    },

    :flavor => {
      # FIXME: Change tagging_edit to POST only; We need to remove the redirects
      # in app/controllers/application_controller/tags.rb#tag that are used in
      # a role of a method call.
      # Then remove this route from all other controllers too.
      :get => %w(
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        download_data
        index
        show
        show_list
        tagging_edit
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        exp_button
        exp_changed
        exp_token_pressed
        quick_search
        panel_control
        save_col_widths
        sections_field_changed
        show
        show_list
        tag_edit_form_field_changed
        tagging_edit
      )
    },

    :host  => {
      :get => %w(
        advanced_settings
        compare_miq
        compare_to_csv
        compare_to_txt
        compare_to_pdf
        dialog_load
        discover
        discover_field_changed
        download_data
        drift
        drift_history
        drift_to_csv
        drift_to_pdf
        drift_to_txt
        edit
        filesystems
        firewall_rules
        groups
        guest_applications
        host_services
        index
        list
        new
        patches
        perf_top_chart
        protect
        show
        show_association
        show_details
        show_list
        start
        tagging_edit
        users
        ),
      :post => %w(
        advanced_settings
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        create
        dialog_field_changed
        dialog_form_button_pressed
        discover
        discover_field_changed
        drift_all
        drift_compress
        drift_differences
        drift_mode
        drift_same
        dynamic_list_refresh
        exp_button
        exp_changed
        exp_token_pressed
        filesystems
        firewall_rules
        firewallrules
        form_field_changed
        groups
        guest_applications
        host_services
        listnav_search_selected
        quick_search
        panel_control
        patches
        perf_chart_chooser
        perf_top_chart
        protect
        save_col_widths
        save_default_search
        sections_field_changed
        show
        show_list
        squash_toggle
        tag_edit_form_field_changed
        tagging_edit
        tl_chooser
        toggle_policy_profile
        update
        users
        wait_for_task
        )
    },

    :miq_ae_class => {
      :get => %w(
        explorer
      ),
      :post => %w(
        ae_tree_select
        ae_tree_select_toggle
        change_tab
        copy_objects
        create
        create_instance
        create_method
        create_ns
        domains_priority_edit
        explorer
        expand_toggle
        field_accept
        field_delete
        field_method_accept
        field_method_delete
        field_method_select
        field_select
        fields_form_field_changed
        fields_seq_edit
        fields_seq_field_changed
        form_copy_objects_field_changed
        form_field_changed
        form_instance_field_changed
        form_method_field_changed
        form_ns_field_changed
        priority_form_field_changed
        reload
        tree_select
        tree_autoload_dynatree
        update
        update_fields
        update_instance
        update_method
        update_ns
        validate_method_data
        x_button
        x_history
        x_settings_changed
        x_show
      )
    },
    :miq_ae_customization => {
      :get => %w(
        explorer
        export_service_dialogs
        review_import
        service_dialog_json
      ),
      :post => %w(
        ab_group_reorder
        ae_tree_select
        ae_tree_select_toggle
        accordion_select
        automate_button_field_changed
        button_create
        button_update
        cancel_import
        change_tab
        dialog_edit
        dialog_form_field_changed
        dialog_list
        dialog_res_remove
        dialog_res_reorder
        explorer
        field_value_accept
        field_value_delete
        field_value_select
        group_create
        group_form_field_changed
        group_reorder_field_changed
        group_update
        import_service_dialogs
        old_dialogs_form_field_changed
        old_dialogs_list
        old_dialogs_update
        reload
        resolve
        save_col_widths
        tree_autoload_dynatree
        tree_select
        upload_import_file
        x_button
        x_history
        x_settings_changed
        x_show
      )
    },

    :miq_ae_tools => {
      :get => %w(
        automate_json
        export_datastore
        fetch_log
        import_export
        log
        resolve
        review_import
      ),
      :post => %w(
        button
        cancel_import
        form_field_changed
        import_automate_datastore
        reset_datastore
        resolve
        upload
        upload_import_file
        wait_for_task
      )
    },

    :miq_capacity => {
      :get => %w(
        bottlenecks
        index
        planning
        planning_report_download
        util_report_download
        utilization
      ),
      :post => %w(
        bottleneck_tl_chooser
        change_tab
        optimize_tree_select
        planning
        planning_option_changed
        tree_autoload_dynatree
        util_chart_chooser
        wait_for_task
      )
    },

    :miq_policy             => {
      :get  => %w(
        explorer
        export
        fetch_log
        fetch_yaml
        get_json
        import
        index
        log
        rsop
      ),
      :post => %w(
        accordion_select
        action_edit
        action_field_changed
        action_get_all
        action_tag_pressed
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        alert_delete
        alert_edit
        alert_field_changed
        alert_get_all
        alert_profile_assign
        alert_profile_assign_changed
        alert_profile_delete
        alert_profile_edit
        alert_profile_field_changed
        button
        condition_edit
        condition_field_changed
        event_edit
        export
        export_field_changed
        exp_button
        exp_changed
        exp_token_pressed
        import
        panel_control
        policy_edit
        policy_get_all
        policy_field_changed
        profile_edit
        profile_field_changed
        quick_search
        reload
        rsop
        rsop_option_changed
        rsop_show_options
        rsop_toggle
        tree_autoload_dynatree
        tree_select
        upload
        wait_for_task
        x_button
        x_history
        x_search_by_name
        x_settings_changed
        x_show
      )
    },

    :miq_proxy              => {
      :get => %w(
        change_tab
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        download_data
        edit
        fetch_zip
        get_log
        index
        install_007
        jobs
        log_viewer
        new
        protect
        show
        show_list
        tagging
        tasks_show_option
      ),
      :post => %w(
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        create
        credential_field_changed
        form_field_changed
        get_log
        install_007
        jobs
        panel_control
        protect
        sections_field_changed
        show
        show_list
        tasks_button
        tasks_change_options
        update
      )
    },

    :miq_request            => {
      # FIXME: Change stamp to POST only; We need to remove the redirect
      :get  => %w(
        index
        pre_prov
        prov_copy
        prov_edit
        show
        show_list
        stamp
      ),
      :post => %w(
        button
        dialog_field_changed
        dynamic_list_refresh
        post_install_callback
        pre_prov
        prov_button
        prov_change_options
        prov_continue
        prov_edit
        prov_field_changed
        prov_load_tab
        prov_show_option
        request_copy
        request_edit
        retrieve_email
        save_col_widths
        show_list
        sort_ds_grid
        sort_host_grid
        sort_iso_img_grid
        sort_pxe_img_grid
        sort_template_grid
        sort_vc_grid
        sort_vm_grid
        sort_windows_image_grid
        stamp
        stamp_field_changed
        vm_pre_prov
        upload
      )
    },

    :miq_template           => {
      :get  => %w(
        edit
        show
        ownership
      ),
      :post => %w(
        edit
        edit_vm
        form_field_changed
        ownership
        ownership_field_changed
        ownership_update
        show
      )
    },

    :miqservices            => {
      :post => %w(api)
    },
    :ontap_file_share       => {
      :get => %w(
        cim_base_storage_extents
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        create_ds
        download_data
        index
        protect
        show
        show_list
        snia_local_file_systems
        tagging_edit
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        create_ds
        create_ds_field_changed
        exp_button
        exp_changed
        exp_token_pressed
        panel_control
        protect
        quick_search
        save_col_widths
        sections_field_changed
        show
        show_list
        tag_edit_form_field_changed
        tagging_edit
      )
    },
    :ontap_logical_disk     => {
      :get  => %w(
        cim_base_storage_extents
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        download_data
        index
        protect
        show
        show_list
        snia_local_file_systems
        tagging_edit
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        exp_button
        exp_changed
        exp_token_pressed
        panel_control
        perf_chart_chooser
        protect
        quick_search
        save_col_widths
        sections_field_changed
        show
        show_list
        tag_edit_form_field_changed
        tagging_edit
        wait_for_task
      )
    },
    :ontap_storage_system   => {
      :get  => %w(
        cim_base_storage_extents
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        create_ld
        download_data
        index
        protect
        show
        show_list
        snia_local_file_systems
        tagging_edit
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        create_ld
        create_ld_field_changed
        exp_button
        exp_changed
        exp_token_pressed
        panel_control
        protect
        quick_search
        save_col_widths
        sections_field_changed
        show
        show_list
        tag_edit_form_field_changed
        tagging_edit
      )
    },
    :ontap_storage_volume   => {
      :get => %w(
        cim_base_storage_extents
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        download_data
        index
        protect
        show
        show_list
        tagging_edit
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        exp_button
        exp_changed
        exp_token_pressed
        panel_control
        protect
        quick_search
        save_col_widths
        sections_field_changed
        show
        show_list
        tag_edit_form_field_changed
        tagging_edit
      )
    },
    :ops => {
      :get => %w(
        explorer
        fetch_audit_log
        fetch_build
        fetch_log
        fetch_production_log
        show_product_update
      ),
      :post => %w(
        accordion_select
        activate
        apply_imports
        ap_ce_delete
        ap_ce_select
        ap_edit
        ap_form_field_changed
        ap_set_active_tab
        aps_list
        category_delete
        category_edit
        category_field_changed
        category_update
        ce_accept
        ce_delete
        ce_new_cat
        ce_select
        change_tab
        cu_collection_field_changed
        cu_collection_update
        cu_repair
        cu_repair_field_changed
        db_backup
        db_backup_form_field_changed
        db_gc_collection
        db_list
        diagnostics_server_list
        diagnostics_tree_select
        diagnostics_worker_selected
        edit_rhn
        explorer
        fetch_build
        forest_accept
        forest_form_field_changed
        forest_select
        log_depot_edit
        log_depot_field_changed
        log_depot_validate
        orphaned_records_delete
        perf_chart_chooser
        product_updates_list
        rbac_group_edit
        rbac_group_field_changed
        rbac_group_seq_edit
        rbac_group_user_lookup
        rbac_groups_list
        rbac_role_edit
        rbac_role_field_changed
        rbac_roles_list
        rbac_tags_edit
        rbac_user_edit
        rbac_user_field_changed
        rbac_users_list
        region_edit
        region_form_field_changed
        repo_default_name
        restart_server
        rhn_buttons
        rhn_default_server
        rhn_validate
        schedule_edit
        schedule_form_field_changed
        schedules_list
        schedule_update
        settings_form_field_changed
        settings_update
        show
        show_product_update
        smartproxy_affinity_field_changed
        tag_edit_form_field_changed
        tl_chooser
        tree_autoload_dynatree
        tree_select
        upload_csv
        upload_form_field_changed
        upload_login_logo
        upload_logo
        validate_replcation_worker
        wait_for_task
        x_button
        x_show
        zone_edit
        zone_field_changed
      )
    },
    :pxe => {
      :get => %w(
        explorer
      ),
      :post => %w(
        accordion_select
        explorer
        iso_datastore_create
        iso_datastore_form_field_changed
        iso_datastore_list
        iso_image_edit
        iso_img_form_field_changed
        log_depot_validate
        pxe_image_edit
        pxe_image_type_edit
        pxe_image_type_form_field_changed
        pxe_image_type_list
        pxe_img_form_field_changed
        pxe_server_create_update
        pxe_server_form_field_changed
        pxe_server_list
        pxe_wimg_edit
        pxe_wimg_form_field_changed
        reload
        template_create_update
        template_form_field_changed
        template_list
        tree_autoload_dynatree
        tree_select
        x_button
        x_history
        x_settings_changed
      )
    },

    :report       => {
      :get => %w(
        db_widget_dd_done
        download_report
        explorer
        export_widgets
        miq_report_edit
        miq_report_new
        preview_chart
        preview_timeline
        render_chart
        report_only
        review_import
        sample_chart
        sample_timeline
        send_report_data
        widget_json
      ),
      :post => %w(
        accordion_select
        cancel_import
        change_tab
        create
        db_edit
        db_form_field_changed
        db_seq_edit
        db_widget_remove
        discard_changes
        exp_button
        exp_changed
        exp_token_pressed
        explorer
        export_field_changed
        filter_change
        form_field_changed
        get_report
        import_widgets
        menu_editor
        menu_field_changed
        menu_folder_message_display
        menu_update
        miq_report_edit
        reload
        rep_change_tab
        saved_report_paging
        schedule_edit
        schedule_form_field_changed
        show_preview
        show_saved
        tree_autoload_dynatree
        tree_select
        upload
        upload_widget_import_file
        wait_for_task
        widget_edit
        widget_form_field_changed
        widget_shortcut_remove
        widget_shortcut_reset
        x_button
        x_history
        x_settings_changed
        x_show
      )
    },

    :repository => {
      :get => %w(
        compare_miq
        compare_to_csv
        compare_to_txt
        compare_to_pdf
        download_data
        edit
        index
        new
        protect
        show
        show_list
        tagging_edit
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        create
        exp_button
        exp_changed
        exp_token_pressed
        form_field_changed
        listnav_search_selected
        quick_search
        panel_control
        protect
        save_col_widths
        save_default_search
        show
        show_list
        tag_edit_form_field_changed
        tagging_edit
        update
      )
    },

    :resource_pool => {
      :get => %w(
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        download_data
        index
        protect
        show
        show_list
        tagging_edit
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        exp_button
        exp_changed
        exp_token_pressed
        panel_control
        protect
        save_col_widths
        sections_field_changed
        show
        show_list
        tagging_edit
        tag_edit_form_field_changed
        quick_search
      )
    },
    :security_group => {
      :get => %w(
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        index
        show
        show_list
        tagging_edit
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        exp_button
        exp_changed
        exp_token_pressed
        quick_search
        panel_control
        save_col_widths
        show
        show_list
        tag_edit_form_field_changed
        tagging_edit
      )
    },

    :service => {
      :get  => %w(
        download_data
        explorer
        show
      ),
      :post => %w(
        button
        dialog_field_changed
        dialog_form_button_pressed
        dynamic_list_refresh
        explorer
        ownership_field_changed
        ownership_update
        reload
        retire
        retire_date_changed
        save_col_widths
        service_edit
        service_form_field_changed
        service_tag
        tag_edit_form_field_changed
        tree_autoload_dynatree
        tree_select
        x_button
        x_history
        x_settings_changed
        x_show
      )
    },

    # TODO: revisit this controller/route, might be removed after other storage issues are sorted out
    :snia_local_file_system => {
      :get  => %w(show)
    },

    :storage                => {
      :get  => %w(
        button
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        debris_files
        disk_files
        download_data
        files
        index
        perf_chart_chooser
        protect
        show
        show_list
        snapshot_files
        tagging_edit
        vm_ram_files
        vm_misc_files
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_toggle
        adv_search_load_choice
        adv_search_name_typed
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        dynamic_list_refresh
        exp_button
        exp_changed
        exp_token_pressed
        files
        listnav_search_selected
        panel_control
        perf_chart_chooser
        protect
        quick_search
        save_col_widths
        save_default_search
        sections_field_changed
        show
        show_association
        show_details
        show_list
        tag_edit_form_field_changed
        tagging_edit
        wait_for_task
      )
    },

    :storage_manager        => {
      :get  => %w(
        download_data
        edit
        index
        new
        show
        show_list
      ),
      :post => %w(
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        create
        exp_button
        exp_changed
        exp_token_pressed
        form_field_changed
        panel_control
        quick_search
        save_col_widths
        show
        show_list
        update
      )
    },

    :support                => {
      :get  => %w(index)
    },

    :vm                     => {
      :get  => %w(
        download_data
        edit
        ownership
        policy_sim
        reconfigure
        retire
        right_size
        show
        show_list
      ),
      :post => %w(
        edit_vm
        form_field_changed
        ownership
        ownership_field_changed
        ownership_update
        policy_sim
        policy_sim_add
        policy_sim_remove
        pre_prov
        pre_prov_continue
        provision
        reconfigure
        reconfigure_field_changed
        reconfigure_update
        retire
        retire_date_changed
        right_size
        set_checked_items
        show_list
        vmtree_selected
      )
    },

    :vm_cloud               => {
      :get  => %w(
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        download_data
        drift_to_csv
        drift_to_pdf
        drift_to_txt
        explorer
        perf_chart_chooser
        protect
        show
        tagging_edit
      ),
      :post => %w(
        advanced_settings
        accordion_select
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        dialog_form_button_pressed
        dialog_field_changed
        drift_all
        drift_compress
        drift_differences
        drift_history
        drift_mode
        drift_same
        dynamic_list_refresh
        edit_vm
        event_logs
        evm_relationship_field_changed
        evm_relationship_update
        explorer
        exp_button
        exp_changed
        exp_token_pressed
        filesystems
        filesystem_drivers
        form_field_changed
        guest_applications
        groups
        kernel_drivers
        linux_initprocesses
        ownership_field_changed
        ownership_update
        panel_control
        patches
        perf_chart_chooser
        policies
        policy_options
        policy_show_options
        policy_sim
        policy_sim_add
        policy_sim_remove
        pre_prov
        pre_prov_continue
        processes
        protect
        prov_edit
        prov_field_changed
        quick_search
        registry_items
        reload
        retire
        retire_date_changed
        save_col_widths
        scan_histories
        sections_field_changed
        security_groups
        show
        squash_toggle
        tagging_edit
        tag_edit_form_field_changed
        tl_chooser
        tree_autoload_dynatree
        tree_select
        users
        vm_pre_prov
        wait_for_task
        win32_services
        x_button
        x_history
        x_search_by_name
        x_settings_changed
        x_show
      )
    },

    :vm_infra               => {
      :get  => %w(
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        download_data
        drift_to_csv
        drift_to_pdf
        drift_to_txt
        explorer
        launch_vmware_console
        perf_chart_chooser
        policies
        protect
        show
        tagging_edit
      ),
      :post => %w(
        accordion_select
        advanced_settings
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        dialog_field_changed
        dialog_form_button_pressed
        drift_all
        drift_compress
        drift_differences
        drift_history
        drift_mode
        drift_same
        dynamic_list_refresh
        edit_vm
        event_logs
        evm_relationship_field_changed
        evm_relationship_update
        explorer
        exp_button
        exp_changed
        exp_token_pressed
        filesystems
        filesystem_drivers
        form_field_changed
        guest_applications
        groups
        kernel_drivers
        linux_initprocesses
        ontap_file_shares
        ontap_logical_disks
        ontap_storage_systems
        ontap_storage_volume
        ownership_field_changed
        ownership_update
        panel_control
        patches
        perf_chart_chooser
        policies
        policy_options
        policy_show_options
        policy_sim
        policy_sim_add
        policy_sim_remove
        protect
        processes
        pre_prov
        pre_prov_continue
        prov_edit
        prov_field_changed
        quick_search
        reconfigure_field_changed
        reconfigure_update
        registry_items
        reload
        retire
        retire_date_changed
        save_col_widths
        scan_histories
        sections_field_changed
        security_groups
        show
        snap_pressed
        snap_vm
        sort_ds_grid
        sort_host_grid
        sort_iso_img_grid
        sort_vm_grid
        squash_toggle
        tagging_edit
        tag_edit_form_field_changed
        tl_chooser
        tree_autoload_dynatree
        tree_select
        users
        vmrc_console
        vm_pre_prov
        wait_for_task
        win32_services
        x_button
        x_history
        x_search_by_name
        x_settings_changed
        x_show
      )
    },

    :vm_or_template => {
      :get => %w(
        compare_miq
        compare_to_csv
        compare_to_pdf
        compare_to_txt
        download_data
        drift_to_csv
        drift_to_pdf
        drift_to_txt
        explorer
        launch_vmware_console
        protect
        show
        tagging_edit
        util_report_download
        utilization
        vm_show
      ),
      :post => %w(
        accordion_select
        adv_search_button
        adv_search_clear
        adv_search_load_choice
        adv_search_name_typed
        adv_search_toggle
        advanced_settings
        button
        compare_choose_base
        compare_compress
        compare_miq
        compare_miq_all
        compare_miq_differences
        compare_miq_same
        compare_mode
        compare_remove
        compare_set_state
        console
        dialog_field_changed
        dialog_form_button_pressed
        drift_all
        drift_differences
        drift_history
        drift_mode
        drift_same
        dynamic_list_refresh
        edit_vm
        event_logs
        evm_relationship_field_changed
        evm_relationship_update
        exp_button
        exp_changed
        exp_token_pressed
        explorer
        filesystem_drivers
        filesystems
        form_field_changed
        groups
        guest_applications
        kernel_drivers
        linux_initprocesses
        ontap_file_shares
        ontap_logical_disks
        ontap_storage_systems
        ownership_field_changed
        ownership_update
        panel_control
        patches
        perf_chart_chooser
        policies
        policy_options
        policy_show_options
        policy_sim
        policy_sim_add
        policy_sim_remove
        pre_prov
        pre_prov_continue
        processes
        protect
        prov_edit
        prov_field_changed
        quick_search
        reconfigure_field_changed
        reconfigure_update
        registry_items
        reload
        retire
        retire_date_changed
        save_col_widths
        scan_histories
        sections_field_changed
        show
        snap_pressed
        snap_vm
        sort_ds_grid
        sort_host_grid
        sort_iso_img_grid
        squash_toggle
        tagging_edit
        tag_edit_form_field_changed
        tl_chooser
        tree_select
        users
        util_chart_chooser
        vm_pre_prov
        vmrc_console
        vnc_console
        wait_for_task
        win32_services
        x_button
        x_history
        x_search_by_name
        x_show
      )
    },

    :vmdbws                 => {
      :get  => %w(wsdl),
      :post => %w(api)
    }
  }

  root :to => 'dashboard#login'

  # Enablement for the REST API
  get '/api'           => 'api#show',    :format => 'json'
  get '/api/*suffix'   => 'api#show',    :format => 'json'
  match '/api/*suffix' => 'api#update',  :format => 'json', :via => [:post, :put, :patch]
  match '/api/*suffix' => 'api#destroy', :format => 'json', :via => [:delete]

  CONTROLLER_ACTIONS.each do |controller_name, controller_actions|

    # Default route with no action to controller's index action
    match "#{controller_name}", :controller => controller_name, :action => :index

    # One-by-one get/post routes for defined controllers
    if controller_actions.is_a?(Hash)
      unless controller_actions[:get].nil?
        controller_actions[:get].each do |action_name|
          get "#{controller_name}/#{action_name}(/:id)",
              :action     => action_name,
              :controller => controller_name
        end
      end

      unless controller_actions[:post].nil?
        controller_actions[:post].each do |action_name|
          post "#{controller_name}/#{action_name}(/:id)",
               :action     => action_name,
               :controller => controller_name
        end
      end
    end
  end
end

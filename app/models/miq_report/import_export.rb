module MiqReport::ImportExport
  extend ActiveSupport::Concern

  module ClassMethods
    def view_paths
      @view_paths ||= (
        Vmdb::Plugins.map do |engine|
          path = engine.root.join('product/views')
          path if path.directory?
        end.compact
      )
    end

    def resolve_view_path(file_name, file_name_no_suffix = nil)
      view_paths.each do |path|
        full_path = File.join(path, file_name)
        return full_path if File.exist?(full_path)

        if file_name_no_suffix
          full_path_no_suffix = File.join(path, file_name_no_suffix)
          return full_path_no_suffix if File.exist?(full_path_no_suffix)
        end
      end
      nil
    end

    def import_from_hash(report, options = nil)
      raise _("No Report to Import") if report.nil?

      report = report["MiqReport"] if report.keys.first == "MiqReport"
      if !report["menu_name"] || !report["col_order"] || !report["cols"] || report["rpt_type"] != "Custom"
        raise _("Incorrect format, only policy records can be imported.")
      end

      report[:db_options] ||= report["db_options"]
      report[:db_options].deep_symbolize_keys! if report[:db_options]

      user = options[:user] || User.lookup_by_userid(options[:userid])

      if options[:preserve_owner]
        userid = report.delete("userid")
        group_description = report.delete("group_description")

        report_user = userid.present? ? User.lookup_by_userid(userid) : User.find_by(:id => report["user_id"])
        if report_user.nil?
          _log.warn("User '#{userid.presence || report["user_id"]}' for imported report '#{report["name"]}' was not found")
          report.delete("user_id")
        else
          report["user_id"] = report_user.id
        end

        group = group_description.present? ? MiqGroup.in_my_region.find_by(:description => group_description) : MiqGroup.find_by(:id => report["miq_group_id"])
        if group.nil?
          _log.warn("Group '#{group_description}' for imported report '#{report["name"]}' was not found")
          report.delete("miq_group_id")
        else
          report["miq_group_id"] = group.id
        end

        raise _("Neither user or group to be preserved during import were found") if report_user.nil? && group.nil?
      else
        report["miq_group_id"] = user.current_group_id
        report["user_id"] = user.id
      end

      report["name"] = report.delete("menu_name")
      rep = MiqReport.find_by(:name => report["name"])
      if rep
        # if report exists
        if options[:overwrite]
          # if report exists delete and create new
          if user.report_admin_user? || user.current_group_id == rep.miq_group_id
            msg = "Overwriting Report: [#{report["name"]}]"
            rep.attributes = report
            result = {:message => "Replaced Report: [#{report["name"]}]", :level => :info, :status => :update}
          else
            # if report exists dont overwrite
            msg = "Skipping Report (already in DB under a different group): [#{report["name"]}]"
            result = {:message => msg, :level => :error, :status => :skip}
          end
        else
          # if report exists dont overwrite
          msg = "Skipping Report (already in DB): [#{report["name"]}]"
          result = {:message => msg, :level => :info, :status => :keep}
        end
      else
        # create new report
        msg = "Importing Report: [#{report["name"]}]"
        rep = MiqReport.new(report)
        result = {:message => "Imported Report: [#{report["name"]}]", :level => :info, :status => :add}
      end
      _log.info(msg)

      if options[:save] && result[:status].in?([:add, :update])
        rep.save!
        _log.info("- Completed.")
      end

      return rep, result
    end

    # @param db [Class] name of report (typically class name)
    # @param current_user [User] User for restricted access to reports
    # @param options [Hash]
    # @option options :association [String] used for a view suffix
    # @option options :view_suffix [String] used for a view suffix
    # @param cache [Hash] cache that holds yaml for the views
    def load_from_view_options(db, current_user = nil, options = {}, cache = {})
      filename = MiqReport.view_yaml_filename(db, current_user, options)
      view = load_from_filename(filename, cache)
      view.db = db if filename.ends_with?("Vm__restricted.yaml")
      view
    end

    def load_from_filename(filename, cache)
      yaml = cache[filename] ||= YAML.load_file(filename)
      view = MiqReport.new(yaml)
      view.extras ||= {}                        # Always add in the extras hash
      view.extras[:filename] = File.basename(filename, '.yaml')
      view
    end

    def view_yaml_filename(db, current_user, options)
      suffix = options[:association] || options[:view_suffix]
      db = db.to_s

      role = current_user.try(:miq_user_role)
      # Special code to build the view file name for users of VM restricted roles
      if %w(ManageIQ::Providers::CloudManager::Template ManageIQ::Providers::InfraManager::Template
            ManageIQ::Providers::CloudManager::Vm ManageIQ::Providers::InfraManager::Vm VmOrTemplate).include?(db)
        if role && role.settings && role.settings.fetch_path(:restrictions, :vms)
          viewfilerestricted = resolve_view_path('Vm__restricted.yaml')
        end
      end

      db = db.gsub(/::/, '_')

      role = role.name.split("-").last if role.try(:read_only?)

      suffix = suffix ? "-#{suffix}" : ''

      viewfile = resolve_view_path("#{db}#{suffix}.yaml", "#{db}.yaml")
      viewfilebyrole = resolve_view_path("#{db}#{suffix}-#{role}.yaml")

      viewfilerestricted || viewfilebyrole || viewfile
    end
  end

  def export_to_array
    h = attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    h["menu_name"] = h.delete("name")
    h["userid"] = User.find_by(:id => h["user_id"])&.userid.to_s
    h["group_description"] = MiqGroup.find_by(:id => h["miq_group_id"])&.description.to_s
    [{self.class.to_s => h}]
  end
end

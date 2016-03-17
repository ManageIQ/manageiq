module MiqReport::ImportExport
  extend ActiveSupport::Concern

  module ClassMethods
    def import_from_hash(report, options = nil)
      raise _("No Report to Import") if report.nil?

      report = report["MiqReport"] if report.keys.first == "MiqReport"
      if !report["menu_name"] || !report["col_order"] || !report["cols"] || report["rpt_type"] != "Custom"
        raise _("Incorrect format, only policy records can be imported.")
      end

      user = options[:user] || User.find_by_userid(options[:userid])
      report.merge!("miq_group_id" => user.current_group_id, "user_id" => user.id)

      report["name"] = report.delete("menu_name")
      rep = MiqReport.find_by_name(report["name"])
      if rep
        # if report exists
        if options[:overwrite]
          # if report exists delete and create new
          if user.admin_user? || user.current_group_id == rep.miq_group_id
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
      _log.info("#{msg}")

      if options[:save] && result[:status].in?([:add, :update])
        rep.save!
        _log.info("- Completed.")
      end

      return rep, result
    end
  end

  def export_to_array
    h = attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    h["menu_name"] = h.delete("name")
    [{self.class.to_s => h}]
  end
end

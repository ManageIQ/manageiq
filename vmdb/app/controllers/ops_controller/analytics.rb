# Analytics Accordion methods included in OpsController.rb
module OpsController::Analytics
  extend ActiveSupport::Concern

  def analytics_tree_select
    typ, id = params[:id].split("_")
    case typ
    when "server"
      @record = session[:tree_selection] = MiqServer.find(from_cid(id))
    when "role"
      @record = session[:tree_selection] = ServerRole.find(from_cid(id))
    when "asr"
      @record = session[:tree_selection] = AssignedServerRole.find(from_cid(id))
    end
    #@_params[:treestate] = true                  # Force restore of saved tree open state
    zone = Zone.find_by_id(from_cid(x_node.split('-').last))
    session[:server_tree] = build_server_tree(zone).to_json
    refresh_screen
  end

  private #######################

  def analytics_build_tree
    TreeBuilderOpsAnalytics.new("analytics_tree", "analytics", @sb)
  end

  # Get information for a policy
  def analytics_get_info(nodetype)
    @sb[:active_tab] = "analytics_details"
    if x_node.split('-').first == "z"
      zone = Zone.find_by_id(from_cid(x_node.split('-').last))
      @sb[:rpt_title] = "Analytics Report for '#{zone.description}'"
      @right_cell_text = @sb[:my_zone] == zone.name ?
        I18n.t("cell_header.type_of_model_record_current)",
                                  :typ=>"Diagnostics",
                                  :model=>ui_lookup(:model=>zone.class.to_s),
                                  :name=>zone.description) :
        I18n.t("cell_header.type_of_model_record)",
                                  :typ=>"Diagnostics",
                                  :model=>ui_lookup(:model=>zone.class.to_s),
                                  :name=>zone.description)
    elsif x_node.split('-').first == "svr"
      svr = MiqServer.find(from_cid(nodetype.downcase.split("-").last))
      @sb[:rpt_title] = "Analytics Report for '#{svr.name} [#{svr.id}]'"
      @right_cell_text = @sb[:my_server_id] == svr.id ?
        I18n.t("cell_header.type_of_model_record_current)",
                                  :typ=>"Diagnostics",
                                  :model=>ui_lookup(:model=>svr.class.to_s),
                                  :name=>"#{svr.name} [#{svr.id.to_s}]") :
        I18n.t("cell_header.type_of_model_record)",
                                  :typ=>"Diagnostics",
                                  :model=>ui_lookup(:model=>svr.class.to_s),
                                  :name=>"#{svr.name} [#{svr.id.to_s}]")
    else
      @right_cell_text = _("%{model} \"%{name}\"") % {:name=>"Enterprise", :model=>"Analytics"}
      @sb[:rpt_title] = "Analytics Report for Enterprise"
    end
    analytics_gen_report
  end

  def analytics_gen_report
    typ,id = get_rtype_rid
    fname = "analytics.yaml"
    @sb[:analytics_rpt] = MiqReport.new(YAML::load(File.open("#{OPS_REPORTS_FOLDER}/#{fname}")))
    @sb[:analytics_rpt].title = @sb[:analytics_rpt].name = @sb[:rpt_title]
    @sb[:analytics_rpt].db_options = {:options=>{:resource_type =>typ, :resource_id => id}, :rpt_type=>"analytics"}
    #@sb[:analytics_rpt].generate_table
  end

  def get_rtype_rid
    node = x_node.split("-")
    case node[0]
    when "svr"
      rtype = "MiqServer"
    when "z"
      rtype = "Zone"
    else
      rtype = "MiqEnterprise"
    end
    id = rtype == "MiqEnterprise" ? 1 : node[1]
    return rtype,id
  end
end

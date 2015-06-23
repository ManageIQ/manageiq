require "spec_helper"
include UiConstants

describe ReportController do

  context "Get form variables" do

    context "press col buttons" do
      it "moves columns left" do
        controller.instance_variable_set(:@_params, {:button => "left"})
        controller.should_receive(:move_cols_left)
        controller.send(:gfv_move_cols_buttons)
      end

      it "moves columns right" do
        controller.instance_variable_set(:@_params, {:button => "right"})
        controller.should_receive(:move_cols_right)
        controller.send(:gfv_move_cols_buttons)
      end

      it "moves columns up" do
        controller.instance_variable_set(:@_params, {:button => "up"})
        controller.should_receive(:move_cols_up)
        controller.send(:gfv_move_cols_buttons)
      end

      it "moves columns down" do
        controller.instance_variable_set(:@_params, {:button => "down"})
        controller.should_receive(:move_cols_down)
        controller.send(:gfv_move_cols_buttons)
      end

      it "moves columns top" do
        controller.instance_variable_set(:@_params, {:button => "top"})
        controller.should_receive(:move_cols_top)
        controller.send(:gfv_move_cols_buttons)
      end

      it "moves columns bottom" do
        controller.instance_variable_set(:@_params, {:button => "bottom"})
        controller.should_receive(:move_cols_bottom)
        controller.send(:gfv_move_cols_buttons)
      end
    end

    context "handle input fields" do
      before :each do
        controller.instance_variable_set(:@edit, {:new => {} })  # Editor methods need @edit[:new]
        controller.stub(:build_edit_screen)                  # Don't actually build the edit screen
      end

      context "handle report fields" do
        it "sets pdf page size" do
          ps = "US-Legal"
          controller.instance_variable_set(:@_params, {:pdf_page_size => ps})
          controller.send(:gfv_report_fields)
          assigns(:edit)[:new][:pdf_page_size].should == ps
        end

        it "sets queue timeout" do
          to = "1"
          controller.instance_variable_set(:@_params, {:chosen_queue_timeout => to})
          controller.send(:gfv_report_fields)
          assigns(:edit)[:new][:queue_timeout].should == to.to_i
        end

        it "clears queue timeout" do
          to = ""
          controller.instance_variable_set(:@_params, {:chosen_queue_timeout => to})
          controller.send(:gfv_report_fields)
          assigns(:edit)[:new][:queue_timeout].should be_nil
        end

        it "sets row limit" do
          rl = "10"
          controller.instance_variable_set(:@_params, {:row_limit => rl})
          controller.send(:gfv_report_fields)
          assigns(:edit)[:new][:row_limit].should == rl
        end

        it "clears row limit" do
          rl = ""
          controller.instance_variable_set(:@_params, {:row_limit => rl})
          controller.send(:gfv_report_fields)
          assigns(:edit)[:new][:row_limit].should == ""
        end

        it "sets report name" do
          rn = "Report Name"
          controller.instance_variable_set(:@_params, {:name => rn})
          controller.send(:gfv_report_fields)
          assigns(:edit)[:new][:name].should == rn
        end

        it "sets report title" do
          rt = "Report Title"
          controller.instance_variable_set(:@_params, {:title => rt})
          controller.send(:gfv_report_fields)
          assigns(:edit)[:new][:title].should == rt
        end
      end

      context "handle model changes" do
        it "sets CI model" do
          model = "Vm"
          controller.instance_variable_set(:@_params, {:chosen_model => model})
          controller.send(:gfv_model)
          assigns(:edit)[:new][:model].should == model
          assigns(:refresh_div).should == "form_div"
          assigns(:refresh_partial).should == "form"
        end

        it "sets performance model" do
          model = "VmPerformance"
          controller.instance_variable_set(:@_params, {:chosen_model => model})
          controller.send(:gfv_model)
          edit_new = assigns(:edit)[:new]
          edit_new[:model].should == model
          edit_new[:perf_interval].should == "daily"
          edit_new[:perf_avgs].should == "time_interval"
          edit_new[:tz].should == session[:user_tz]
          assigns(:edit)[:start_array].should be_an_instance_of(Array)
          assigns(:edit)[:end_array].should be_an_instance_of(Array)
          assigns(:refresh_div).should == "form_div"
          assigns(:refresh_partial).should == "form"
        end

        it "sets chargeback model" do
          model = "Chargeback"
          controller.instance_variable_set(:@_params, {:chosen_model => model})
          controller.send(:gfv_model)
          edit_new = assigns(:edit)[:new]
          edit_new[:model].should == model
          edit_new[:cb_interval].should == "daily"
          edit_new[:cb_interval_size].should == 1
          edit_new[:cb_end_interval_offset].should == 1
          edit_new[:cb_groupby].should == "date"
          edit_new[:tz].should == session[:user_tz]
          assigns(:refresh_div).should == "form_div"
          assigns(:refresh_partial).should == "form"
        end
      end

      context "handle trend field changes" do
        it "sets trend column (non % based)" do
          tc = "VmPerformance-derived_memory_used"
          MiqExpression.stub(:reporting_available_fields).and_return([["Test", tc]]) # Hand back array of arrays
          controller.instance_variable_set(:@_params, {:chosen_trend_col => tc})
          controller.send(:gfv_trend)
          edit = assigns(:edit)
          edit_new = edit[:new]
          edit_new[:perf_trend_db].should == tc.split("-").first
          edit_new[:perf_trend_col].should == tc.split("-").last
          edit_new[:perf_interval].should == "daily"
          edit_new[:perf_target_pct1].should == 100
          edit_new[:perf_limit_val].should be_nil
          edit[:percent_col].should be_false
          edit[:start_array].should be_an_instance_of(Array)
          edit[:end_array].should be_an_instance_of(Array)
          assigns(:refresh_div).should == "columns_div"
          assigns(:refresh_partial).should == "form_columns"
        end

        it "sets trend column (% based)" do
          tc = "VmPerformance-derived_memory_used"
          MiqExpression.stub(:reporting_available_fields).and_return([["Test (%)", tc]]) # Hand back array of arrays
          controller.instance_variable_set(:@_params, {:chosen_trend_col => tc})
          controller.send(:gfv_trend)
          edit = assigns(:edit)
          edit_new = edit[:new]
          edit_new[:perf_trend_db].should == tc.split("-").first
          edit_new[:perf_trend_col].should == tc.split("-").last
          edit_new[:perf_interval].should == "daily"
          edit_new[:perf_target_pct1].should == 100
          edit_new[:perf_limit_val].should == 100
          edit_new[:perf_limit_col].should be_nil
          edit[:percent_col].should be_true
          edit[:start_array].should be_an_instance_of(Array)
          edit[:end_array].should be_an_instance_of(Array)
          assigns(:refresh_div).should == "columns_div"
          assigns(:refresh_partial).should == "form_columns"
        end

        it "clears trend column" do
          tc = "<Choose>"
          controller.instance_variable_set(:@_params, {:chosen_trend_col => tc})
          controller.send(:gfv_trend)
          edit_new = assigns(:edit)[:new]
          edit_new[:perf_trend_db].should be_nil
          edit_new[:perf_trend_col].should be_nil
          edit_new[:perf_interval].should == "daily"
          edit_new[:perf_target_pct1].should == 100
          assigns(:refresh_div).should == "columns_div"
          assigns(:refresh_partial).should == "form_columns"
         end

        it "sets trend limit column" do
          limit_col= "max_derived_cpu_reserved"
          controller.instance_variable_set(:@_params, {:chosen_limit_col => limit_col})
          controller.send(:gfv_trend)
          edit_new = assigns(:edit)[:new]
          edit_new[:perf_limit_col].should == limit_col
          edit_new[:perf_limit_val].should be_nil
          assigns(:refresh_div).should == "columns_div"
          assigns(:refresh_partial).should == "form_columns"
        end

        it "clears trend limit column" do
          limit_col = "<None>"
          controller.instance_variable_set(:@_params, {:chosen_limit_col => limit_col})
          controller.send(:gfv_trend)
          assigns(:edit)[:new][:perf_limit_col].should be_nil
          assigns(:refresh_div).should == "columns_div"
          assigns(:refresh_partial).should == "form_columns"
        end

        it "sets trend limit value" do
          limit_val = "50"
          controller.instance_variable_set(:@_params, {:chosen_limit_val => limit_val})
          controller.send(:gfv_trend)
          assigns(:edit)[:new][:perf_limit_val].should == limit_val
        end

        it "sets trend limit percent 1" do
          pct = "70"
          controller.instance_variable_set(:@_params, {:percent1 => pct})
          controller.send(:gfv_trend)
          assigns(:edit)[:new][:perf_target_pct1].should == pct.to_i
        end

        it "sets trend limit percent 2" do
          pct = "80"
          controller.instance_variable_set(:@_params, {:percent2 => pct})
          controller.send(:gfv_trend)
          assigns(:edit)[:new][:perf_target_pct2].should == pct.to_i
        end

        it "sets trend limit percent 3" do
          pct = "90"
          controller.instance_variable_set(:@_params, {:percent3 => pct})
          controller.send(:gfv_trend)
          assigns(:edit)[:new][:perf_target_pct3].should == pct.to_i
        end
      end

      context "handle performance field changes" do
        it "sets perf interval" do
          perf_int = "hourly"
          controller.instance_variable_set(:@_params, {:chosen_interval => perf_int})
          controller.send(:gfv_performance)
          edit = assigns(:edit)
          edit_new = edit[:new]
          edit_new[:perf_interval].should == perf_int
          edit_new[:perf_start].should == 1.day.to_s
          edit_new[:perf_end].should == "0"
          edit[:start_array].should be_an_instance_of(Array)
          edit[:end_array].should be_an_instance_of(Array)
          assigns(:refresh_div).should == "form_div"
          assigns(:refresh_partial).should == "form"
        end

        it "sets perf averages" do
          perf_avg = "active_data"
          controller.instance_variable_set(:@_params, {:perf_avgs => perf_avg})
          controller.send(:gfv_performance)
          assigns(:edit)[:new][:perf_avgs].should == perf_avg
        end

        it "sets perf start" do
          perf_start = 3.days.to_s
          controller.instance_variable_set(:@_params, {:chosen_start => perf_start})
          controller.send(:gfv_performance)
          assigns(:edit)[:new][:perf_start].should == perf_start
        end

        it "sets perf end" do
          perf_end = 1.days.to_s
          controller.instance_variable_set(:@_params, {:chosen_end => perf_end})
          controller.send(:gfv_performance)
          assigns(:edit)[:new][:perf_end].should == perf_end
        end

        it "sets perf time zone" do
          tz = "Pacific Time (US & Canada)"
          controller.instance_variable_set(:@_params, {:chosen_tz => tz})
          controller.send(:gfv_performance)
          assigns(:edit)[:new][:tz].should == tz
        end

        it "sets perf time profile" do
          time_prof = FactoryGirl.create(:time_profile, :description => "Test", :profile=> {:tz => "UTC"})
          chosen_time_prof = time_prof.id.to_s
          controller.instance_variable_set(:@_params, {:chosen_time_profile => chosen_time_prof})
          controller.send(:gfv_performance)
          edit_new = assigns(:edit)[:new]
          edit_new[:time_profile].should == chosen_time_prof.to_i
        end

        it "clears perf time profile" do
          chosen_time_prof = ""
          controller.instance_variable_set(:@_params, {:chosen_time_profile => chosen_time_prof})
          controller.send(:gfv_performance)
          edit_new = assigns(:edit)[:new]
          edit_new[:time_profile].should be_nil
          edit_new[:time_profile_tz].should be_nil
          assigns(:refresh_div).should == "filter_div"
          assigns(:refresh_partial).should == "form_filter"
        end
      end

      context "handle chargeback field changes" do
        it "sets show costs" do
          show_type = "owner"
          controller.instance_variable_set(:@_params, {:cb_show_typ => show_type})
          controller.send(:gfv_chargeback)
          assigns(:edit)[:new][:cb_show_typ].should == show_type
          assigns(:refresh_div).should == "filter_div"
          assigns(:refresh_partial).should == "form_filter"
        end

        it "clears show costs" do
          show_type = ""
          controller.instance_variable_set(:@_params, {:cb_show_typ => show_type})
          controller.send(:gfv_chargeback)
          assigns(:edit)[:new][:cb_show_typ].should be_nil
          assigns(:refresh_div).should == "filter_div"
          assigns(:refresh_partial).should == "form_filter"
        end

        it "sets tag category" do
          tag_cat = "department"
          controller.instance_variable_set(:@_params, {:cb_tag_cat => tag_cat})
          cl_rec = FactoryGirl.create(:classification, :name => "test_name", :description=> "Test Description")
          Classification.should_receive(:find_by_name).and_return([cl_rec])
          controller.send(:gfv_chargeback)
          assigns(:edit)[:new][:cb_tag_cat].should == tag_cat
          assigns(:edit)[:cb_tags].should be_a_kind_of(Hash)
          assigns(:refresh_div).should == "filter_div"
          assigns(:refresh_partial).should == "form_filter"
        end

        it "clears tag category" do
          tag_cat = ""
          controller.instance_variable_set(:@_params, {:cb_tag_cat => tag_cat})
          controller.send(:gfv_chargeback)
          edit_new = assigns(:edit)[:new]
          edit_new[:cb_tag_cat].should be_nil
          edit_new[:cb_tag_value].should be_nil
          assigns(:refresh_div).should == "filter_div"
          assigns(:refresh_partial).should == "form_filter"
        end

        it "sets owner id" do
          owner_id = "admin"
          controller.instance_variable_set(:@_params, {:cb_owner_id => owner_id})
          controller.send(:gfv_chargeback)
          assigns(:edit)[:new][:cb_owner_id].should == owner_id
        end

        it "sets tag value" do
          tag_val = "accounting"
          controller.instance_variable_set(:@_params, {:cb_tag_value => tag_val})
          controller.send(:gfv_chargeback)
          assigns(:edit)[:new][:cb_tag_value].should == tag_val
        end

        it "sets group by" do
          group_by = "vm"
          controller.instance_variable_set(:@_params, {:cb_groupby => group_by})
          controller.send(:gfv_chargeback)
          assigns(:edit)[:new][:cb_groupby].should == group_by
        end

        it "sets show costs by" do
          show_costs_by = "day"
          controller.instance_variable_set(:@_params, {:cb_interval => show_costs_by})
          controller.send(:gfv_chargeback)
          edit_new = assigns(:edit)[:new]
          edit_new[:cb_interval].should == show_costs_by
          edit_new[:cb_interval_size].should == 1
          edit_new[:cb_end_interval_offset].should == 1
          assigns(:refresh_div).should == "filter_div"
          assigns(:refresh_partial).should == "form_filter"
        end

        it "sets interval size" do
          int_size = "2"
          controller.instance_variable_set(:@_params, {:cb_interval_size => int_size})
          controller.send(:gfv_chargeback)
          assigns(:edit)[:new][:cb_interval_size].should == int_size.to_i
        end

        it "sets end interval offset" do
          end_int_offset = "2"
          controller.instance_variable_set(:@_params, {:cb_end_interval_offset => end_int_offset})
          controller.send(:gfv_chargeback)
          assigns(:edit)[:new][:cb_end_interval_offset].should == end_int_offset.to_i
        end
      end

      context "handle chart field changes" do
        it "sets chart type" do
          chosen_graph = "Bar"
          controller.instance_variable_set(:@_params, {:chosen_graph => chosen_graph})
          controller.send(:gfv_charts)
          edit_new = assigns(:edit)[:new]
          edit_new[:graph_type].should == chosen_graph
          edit_new[:graph_other].should be_true
          edit_new[:graph_count].should == GRAPH_MAX_COUNT
          assigns(:refresh_div).should == "chart_div"
          assigns(:refresh_partial).should == "form_chart"
        end

        it "clears chart type" do
          chosen_graph = "<No chart>"
          controller.instance_variable_set(:@_params, {:chosen_graph => chosen_graph})
          edit = assigns(:edit)
          edit[:current] = {:graph_count => GRAPH_MAX_COUNT, :graph_other => true}
          controller.instance_variable_set(:@edit, edit)
          controller.send(:gfv_charts)
          edit_new = assigns(:edit)[:new]
          edit_new[:graph_type].should be_nil
          edit_new[:graph_other].should be_true
          edit_new[:graph_count].should == GRAPH_MAX_COUNT
          assigns(:refresh_div).should == "chart_div"
          assigns(:refresh_partial).should == "form_chart"
        end

        it "sets top values to show" do
          top_val = "3"
          controller.instance_variable_set(:@_params, {:chosen_count => top_val})
          controller.send(:gfv_charts)
          assigns(:edit)[:new][:graph_count].should == top_val
          assigns(:refresh_div).should == "chart_sample_div"
          assigns(:refresh_partial).should == "form_chart_sample"
        end

        it "sets sum other values" do
          sum_other = "null"
          controller.instance_variable_set(:@_params, {:chosen_other => sum_other})
          controller.send(:gfv_charts)
          assigns(:edit)[:new][:graph_other].should be_false
          assigns(:refresh_div).should == "chart_sample_div"
          assigns(:refresh_partial).should == "form_chart_sample"
        end
      end

      context "handle consolidation field changes" do
        P1 = "Vm-name"
        P2 = "Vm-boot_time"
        P3 = "Vm-hostname"
        before :each do
          edit = assigns(:edit)
          edit[:pivot_cols] = Hash.new
          controller.instance_variable_set(:@edit, edit)
          controller.should_receive(:build_field_order).once
        end

        it "sets pivot 1" do
          controller.instance_variable_set(:@_params, {:chosen_pivot1 => P1})
          controller.send(:gfv_pivots)
          assigns(:edit)[:new][:pivotby1].should == P1
          assigns(:refresh_div).should == "consolidate_div"
          assigns(:refresh_partial).should == "form_consolidate"
        end

        it "sets pivot 2" do
          controller.instance_variable_set(:@_params, {:chosen_pivot2 => P2})
          controller.send(:gfv_pivots)
          assigns(:edit)[:new][:pivotby2].should == P2
          assigns(:refresh_div).should == "consolidate_div"
          assigns(:refresh_partial).should == "form_consolidate"
        end

        it "sets pivot 3" do
          controller.instance_variable_set(:@_params, {:chosen_pivot3 => P3})
          controller.send(:gfv_pivots)
          assigns(:edit)[:new][:pivotby3].should == P3
          assigns(:refresh_div).should == "consolidate_div"
          assigns(:refresh_partial).should == "form_consolidate"
        end

        it "clearing pivot 1 also clears pivot 2 and 3" do
          edit = assigns(:edit)
          edit[:new][:pivotby1] = P1
          edit[:new][:pivotby2] = P2
          edit[:new][:pivotby3] = P3
          controller.instance_variable_set(:@edit, edit)
          controller.instance_variable_set(:@_params, {:chosen_pivot1 => NOTHING_STRING})
          controller.send(:gfv_pivots)
          edit_new = assigns(:edit)[:new]
          edit_new[:pivotby1].should == NOTHING_STRING
          edit_new[:pivotby2].should == NOTHING_STRING
          edit_new[:pivotby3].should == NOTHING_STRING
          assigns(:refresh_div).should == "consolidate_div"
          assigns(:refresh_partial).should == "form_consolidate"
        end

        it "clearing pivot 2 also clears pivot 3" do
          edit = assigns(:edit)
          edit[:new][:pivotby1] = P1
          edit[:new][:pivotby2] = P2
          edit[:new][:pivotby3] = P3
          controller.instance_variable_set(:@edit, edit)
          controller.instance_variable_set(:@_params, {:chosen_pivot2 => NOTHING_STRING})
          controller.send(:gfv_pivots)
          edit_new = assigns(:edit)[:new]
          edit_new[:pivotby1].should == P1
          edit_new[:pivotby2].should == NOTHING_STRING
          edit_new[:pivotby3].should == NOTHING_STRING
          assigns(:refresh_div).should == "consolidate_div"
          assigns(:refresh_partial).should == "form_consolidate"
        end

        it "setting pivot 1 = pivot 2 bubbles up pivot 3 to 2" do
          edit = assigns(:edit)
          edit[:new][:pivotby1] = P1
          edit[:new][:pivotby2] = P2
          edit[:new][:pivotby3] = P3
          controller.instance_variable_set(:@edit, edit)
          controller.instance_variable_set(:@_params, {:chosen_pivot1 => P2})
          controller.send(:gfv_pivots)
          edit_new = assigns(:edit)[:new]
          edit_new[:pivotby1].should == P2
          edit_new[:pivotby2].should == P3
          edit_new[:pivotby3].should == NOTHING_STRING
          assigns(:refresh_div).should == "consolidate_div"
          assigns(:refresh_partial).should == "form_consolidate"
        end

        it "setting pivot 2 = pivot 3 clears pivot 3" do
          edit = assigns(:edit)
          edit[:new][:pivotby1] = P1
          edit[:new][:pivotby2] = P2
          edit[:new][:pivotby3] = P3
          controller.instance_variable_set(:@edit, edit)
          controller.instance_variable_set(:@_params, {:chosen_pivot2 => P3})
          controller.send(:gfv_pivots)
          edit_new = assigns(:edit)[:new]
          edit_new[:pivotby1].should == P1
          edit_new[:pivotby2].should == P3
          edit_new[:pivotby3].should == NOTHING_STRING
          assigns(:refresh_div).should == "consolidate_div"
          assigns(:refresh_partial).should == "form_consolidate"
        end
      end

      context "handle summary field changes" do
        S1 = "Vm-test1"
        S2 = "Vm-test2"
        before :each do
          edit = assigns(:edit)
          edit[:new][:sortby1] = S1               # Set an initial sort by col
          edit[:new][:sortby2] = S2               # Set no second sort col
          edit[:new][:group] == "No"              # Setting group default
          edit[:new][:col_options] = Hash.new     # Create col_options hash so keys can be set
          edit[:new][:field_order] = Array.new    # Create field_order array
          controller.instance_variable_set(:@edit, edit)
        end

        it "sets first sort col" do
          new_sort = "Vm-new"
          controller.instance_variable_set(:@_params, {:chosen_sort1 => new_sort})
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          edit_new[:sortby1].should == new_sort
          edit_new[:sortby2].should == S2
          assigns(:refresh_div).should == "sort_div"
          assigns(:refresh_partial).should == "form_sort"
        end

        it "set first sort col = second clears second" do
          controller.instance_variable_set(:@_params, {:chosen_sort1 => S2})
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          edit_new[:sortby1].should == S2
          edit_new[:sortby2].should == NOTHING_STRING
          assigns(:refresh_div).should == "sort_div"
          assigns(:refresh_partial).should == "form_sort"
        end

        it "clearing first sort col clears both sort cols" do
          controller.instance_variable_set(:@_params, {:chosen_sort1 => NOTHING_STRING})
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          edit_new[:sortby1].should == NOTHING_STRING
          edit_new[:sortby2].should == NOTHING_STRING
          assigns(:refresh_div).should == "sort_div"
          assigns(:refresh_partial).should == "form_sort"
        end

        it "sets first sort col suffix" do
          sfx = "hour"
          controller.instance_variable_set(:@_params, {:sort1_suffix => sfx})
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          edit_new[:sortby1].should == "#{S1}__#{sfx}"
          edit_new[:sortby2].should == S2
        end

        it "sets sort order" do
          sort_order = "Descending"
          controller.instance_variable_set(:@_params, {:sort_order => sort_order})
          controller.send(:gfv_sort)
          assigns(:edit)[:new][:order].should == sort_order
        end

        it "sets sort breaks" do
          sort_group = "Yes"
          controller.instance_variable_set(:@_params, {:sort_group => sort_group})
          controller.send(:gfv_sort)
          assigns(:edit)[:new][:group].should == sort_group
          assigns(:refresh_div).should == "sort_div"
          assigns(:refresh_partial).should == "form_sort"
        end

        it "sets hide detail rows" do
          hide_detail = "1"
          controller.instance_variable_set(:@_params, {:hide_details => hide_detail})
          controller.send(:gfv_sort)
          assigns(:edit)[:new][:hide_details].should be_true
        end

        # TODO: Not sure why, but this test seems to take .5 seconds while others are way faster
        it "sets format on summary row" do
          fmt = "hour_am_pm"
          controller.instance_variable_set(:@_params, {:break_format => fmt})
          controller.send(:gfv_sort)

          # Check to make sure the proper value gets set in the col_options hash using the last part of the sortby1 col as key
          opts = assigns(:edit)[:new][:col_options]
          key = S1.split("-").last
          opts[key].should be_a_kind_of(Hash)
          opts[key][:break_format].should == fmt.to_sym
        end

        it "sets second sort col" do
          new_sort = "Vm-new"
          controller.instance_variable_set(:@_params, {:chosen_sort2 => new_sort})
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          edit_new[:sortby1].should == S1
          edit_new[:sortby2].should == new_sort
        end

        it "clearing second sort col" do
          controller.instance_variable_set(:@_params, {:chosen_sort2 => NOTHING_STRING})
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          edit_new[:sortby1].should == S1
          edit_new[:sortby2].should == NOTHING_STRING
        end

        it "sets second sort col suffix" do
          sfx = "day"
          controller.instance_variable_set(:@_params, {:sort2_suffix => sfx})
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          edit_new[:sortby1].should == S1
          edit_new[:sortby2].should == "#{S2}__#{sfx}"
        end
      end

      context "handle timeline field changes" do
        before :each do
          col = "Vm-created_on"
          controller.instance_variable_set(:@_params, {:chosen_tl => col})
          controller.send(:gfv_timeline)  # This will set the @edit timeline unit hash keys
        end

        it "sets timeline col" do
          col = "Vm-boot_time"
          controller.instance_variable_set(:@_params, {:chosen_tl => col})
          controller.send(:gfv_timeline)
          assigns(:edit)[:new][:tl_field].should == col
        end

        it "clears timeline col" do
          controller.instance_variable_set(:@_params, {:chosen_tl => NOTHING_STRING})
          controller.send(:gfv_timeline)
          edit = assigns(:edit)
          edit[:new][:tl_field].should == NOTHING_STRING
          edit[:unit1].should == NOTHING_STRING
          edit[:unit2].should == NOTHING_STRING
          edit[:unit3].should == NOTHING_STRING
        end

        it "sets first, second, and third band units" do
          unit1 = "Hour"
          controller.instance_variable_set(:@_params, {:chosen_unit1 => unit1})
          controller.send(:gfv_timeline)
          edit = assigns(:edit)
          edit[:unit1].should == unit1
          edit[:new][:tl_bands][0][:unit].should == unit1
          assigns(:refresh_div).should == "tl_settings_div"
          assigns(:refresh_partial).should == "form_tl_settings"

          unit2 = "Day"
          controller.instance_variable_set(:@_params, {:chosen_unit2 => unit2})
          controller.send(:gfv_timeline)
          edit = assigns(:edit)
          edit[:unit2].should == unit2
          edit[:new][:tl_bands][1][:unit].should == unit2
          assigns(:refresh_div).should == "tl_settings_div"
          assigns(:refresh_partial).should == "form_tl_settings"

          unit3 = "Week"
          controller.instance_variable_set(:@_params, {:chosen_unit3 => unit3})
          controller.send(:gfv_timeline)
          edit = assigns(:edit)
          edit[:unit3].should == unit3
          edit[:new][:tl_bands][2][:unit].should == unit3
          assigns(:refresh_div).should == "tl_settings_div"
          assigns(:refresh_partial).should == "form_tl_settings"
        end

        it "sets event to position at" do
          pos = "First"
          controller.instance_variable_set(:@_params, {:chosen_position => pos})
          controller.send(:gfv_timeline)
          assigns(:edit)[:new][:tl_position].should == pos
          assigns(:tl_changed).should be_true
        end

        it "sets show event from last (unit)" do
          unit = "Minutes"
          controller.instance_variable_set(:@_params, {:chosen_last_unit => unit})
          controller.send(:gfv_timeline)
          edit_new = assigns(:edit)[:new]
          edit_new[:tl_last_unit].should == unit
          edit_new[:tl_last_time].should be_nil
          assigns(:refresh_div).should == "tl_settings_div"
          assigns(:refresh_partial).should == "form_tl_settings"
          assigns(:tl_repaint).should be_true
        end

        it "sets show event from last (value)" do
          val = "10"
          controller.instance_variable_set(:@_params, {:chosen_last_time => val})
          controller.send(:gfv_timeline)
          assigns(:edit)[:new][:tl_last_time].should == val
          assigns(:tl_repaint).should be_true
        end
      end
    end
  end

  context "ReportController::Schedules" do
    before do
      seed_specific_product_features("miq_report_schedule_enable", "miq_report_schedule_disable")
    end

    context "no schedules selected" do
      before do
        controller.stub(:find_checked_items).and_return([])
        controller.should_receive(:render)
        controller.should_receive(:schedule_get_all)
        controller.should_receive(:replace_right_cell)
      end

      it "#miq_report_schedule_enable" do
        controller.miq_report_schedule_enable
        flash_messages = assigns(:flash_array)
        flash_messages.first[:message].should == "No Report Schedules were selected to be enabled"
        flash_messages.first[:level].should == :error
      end

      it "#miq_report_schedule_disable" do
        controller.miq_report_schedule_disable
        flash_messages = assigns(:flash_array)
        flash_messages.first[:message].should == "No Report Schedules were selected to be disabled"
        flash_messages.first[:level].should == :error
      end
    end

    context "normal case" do
      before do
        server = double
        server.stub(:zone_id => 1)
        MiqServer.stub(:my_server).and_return(server)

        @sch = FactoryGirl.create(:miq_schedule, :enabled => true, :updated_at => 1.hour.ago.utc)

        controller.stub(:find_checked_items).and_return([@sch])
        controller.should_receive(:render).never
        controller.should_receive(:schedule_get_all)
        controller.should_receive(:replace_right_cell)
      end

      it "#miq_report_schedule_enable" do
        @sch.update_attribute(:enabled, false)

        controller.miq_report_schedule_enable
        controller.send(:flash_errors?).should_not be_true
        @sch.reload
        @sch.should be_enabled
        @sch.updated_at.should be > 10.minutes.ago.utc
      end

      it "#miq_report_schedule_disable" do
        controller.miq_report_schedule_disable
        controller.send(:flash_errors?).should_not be_true
        @sch.reload
        @sch.should_not be_enabled
        @sch.updated_at.should be > 10.minutes.ago.utc
      end
    end
  end

  describe 'x_button' do
    before(:each) do
      set_user_privileges
    end

    describe 'corresponding methods are called for allowed actions' do
      ReportController::REPORT_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
        it "calls the appropriate method: '#{method}' for action '#{action_name}'" do
          controller.should_receive(method)
          get :x_button, :pressed => action_name
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :pressed => 'random_dude', :format => :html
      expect { response }.to render_template('layouts/exception')
    end
  end

  describe "#export_widgets" do
    include_context "valid session"

    let(:params) { {:widgets => widget_list} }

    before do
      bypass_rescue
    end

    context "when there are widget parameters" do
      let(:widget_list) { %w(1 2 3) }
      let(:widget_yaml) { "the widget yaml" }
      let(:widgets) { [active_record_instance_double("MiqWidget")] }

      before do
        records = widgets
        MiqWidget.stub(:where).with(:id => widget_list).and_return(records)
        MiqWidget.stub(:export_to_yaml).with(widgets, MiqWidget).and_return(widget_yaml)
      end

      it "sends the data" do
        get :export_widgets, params
        response.body.should == "the widget yaml"
      end

      it "sets the filename to the current date" do
        Timecop.freeze(2013, 1, 2) do
          get :export_widgets, params
          response.header['Content-Disposition'].should include("widget_export_20130102_000000.yml")
        end
      end
    end

    context "when there are not widget parameters" do
      let(:widget_list) { nil }

      it "sets a flash message" do
        get :export_widgets, params
        assigns(:flash_array).should == [{
          :message => "At least 1 item must be selected for export",
          :level   => :error
        }]
      end

      it "sets the flash array on the sandbox" do
        get :export_widgets, params
        assigns(:sb)[:flash_msg].should == [{
          :message => "At least 1 item must be selected for export",
          :level   => :error
        }]
      end

      it "redirects to the explorer" do
        get :export_widgets, params
        response.should redirect_to(:action => :explorer)
      end
    end
  end

  describe "#upload_widget_import_file" do
    include_context "valid session"

    let(:widget_import_service) { auto_loaded_instance_double("WidgetImportService") }

    before do
      bypass_rescue
    end

    shared_examples_for "ReportController#upload_widget_import_file that does not upload a file" do
      it "redirects with a warning message" do
        xhr :post, :upload_widget_import_file, params
        response.should redirect_to(
          :action  => :review_import,
          :message => {:message => "Use the browse button to locate an import file", :level => :warning}.to_json
        )
      end
    end

    context "when an upload file is given" do
      let(:filename) { "filename" }
      let(:file) { fixture_file_upload(Rails.root.join("spec/fixtures/files/import_widgets.yml"), "text/yml") }
      let(:params) { {:upload => {:file => file}} }

      before do
        WidgetImportService.stub(:new).and_return(widget_import_service)
      end

      context "when the widget importer does not raise an error" do
        before do
          widget_import_service.stub(:store_for_import).with("the yaml data").and_return(123)
          file.stub(:read).and_return("the yaml data")
        end

        it "redirects to review_import with an import file upload id" do
          xhr :post, :upload_widget_import_file, params
          response.should redirect_to(
            :action                => :review_import,
            :import_file_upload_id => 123,
            :message               => {:message => "Import file was uploaded successfully", :level => :info}.to_json
          )
        end

        it "imports the widgets" do
          widget_import_service.should_receive(:store_for_import).with("the yaml data")
          xhr :post, :upload_widget_import_file, params
        end
      end

      context "when the widget importer raises an import error" do
        before do
          widget_import_service.stub(:store_for_import).and_raise(WidgetImportValidator::NonYamlError)
        end

        it "redirects with an error message" do
          xhr :post, :upload_widget_import_file, params
          response.should redirect_to(
            :action  => :review_import,
            :message => {
              :message => "Error: the file uploaded is not of the supported format",
              :level   => :error
            }.to_json
          )
        end
      end

      context "when the widget importer raises a non valid widget yaml error" do
        before do
          widget_import_service.stub(:store_for_import).and_raise(WidgetImportValidator::InvalidWidgetYamlError)
        end

        it "redirects with an error message" do
          xhr :post, :upload_widget_import_file, params
          response.should redirect_to(
            :action  => :review_import,
            :message => {
              :message => "Error: the file uploaded contains no widgets",
              :level   => :error
            }.to_json
          )
        end
      end
    end

    context "when the upload parameter is nil" do
      let(:params) { {} }

      it_behaves_like "ReportController#upload_widget_import_file that does not upload a file"
    end

    context "when an upload file is not given" do
      let(:params) { {:upload => {:file => nil}} }

      it_behaves_like "ReportController#upload_widget_import_file that does not upload a file"
    end
  end

  describe "#widget_json" do
    include_context "valid session"

    let(:params) { {:import_file_upload_id => "123"} }
    let(:import_file_upload) { active_record_instance_double("ImportFileUpload") }

    before do
      bypass_rescue
      ImportFileUpload.stub(:find).with("123").and_return(import_file_upload)
      import_file_upload.stub(:widget_json).and_return("the widget json")
    end

    it "returns the json" do
      xhr :get, :widget_json, params
      response.body.should == "the widget json"
    end
  end

  describe "#review_import" do
    include_context "valid session"

    let(:params) { {:import_file_upload_id => "123", :message => "the message"} }

    before do
      bypass_rescue
    end

    it "assigns the import file upload id" do
      get :review_import, params
      assigns(:import_file_upload_id).should == "123"
    end

    it "assigns the message" do
      get :review_import, params
      assigns(:message).should == "the message"
    end
  end

  describe "#cancel_import" do
    include_context "valid session"

    let(:params) { {:import_file_upload_id => "123"} }
    let(:widget_import_service) { auto_loaded_instance_double("WidgetImportService") }

    before do
      bypass_rescue
      WidgetImportService.stub(:new).and_return(widget_import_service)
      widget_import_service.stub(:cancel_import)
    end

    it "cancels the import" do
      widget_import_service.should_receive(:cancel_import).with("123")
      xhr :post, :cancel_import, params
    end

    it "returns a 200" do
      xhr :post, :cancel_import, params
      response.status.should == 200
    end

    it "returns the flash messages" do
      xhr :post, :cancel_import, params
      response.body.should == [{:message => "Widget import cancelled", :level => :info}].to_json
    end
  end

  describe "#import_widgets" do
    include_context "valid session"

    let(:widget_import_service) { auto_loaded_instance_double("WidgetImportService") }
    let(:params) { {:import_file_upload_id => "123", :widgets_to_import => ["potato"]} }

    before do
      bypass_rescue
      ImportFileUpload.stub(:where).with(:id => "123").and_return([import_file_upload])
      WidgetImportService.stub(:new).and_return(widget_import_service)
    end

    shared_examples_for "ReportController#import_widgets" do
      it "returns a status of 200" do
        xhr :post, :import_widgets, params
        response.status.should == 200
      end
    end

    context "when the import file upload exists" do
      let(:import_file_upload) { active_record_instance_double("ImportFileUpload") }

      before do
        widget_import_service.stub(:import_widgets)
      end

      it_behaves_like "ReportController#import_widgets"

      it "imports the data" do
        widget_import_service.should_receive(:import_widgets).with(import_file_upload, ["potato"])
        xhr :post, :import_widgets, params
      end

      it "returns the flash message" do
        xhr :post, :import_widgets, params
        response.body.should == [{:message => "Widgets imported successfully", :level => :info}].to_json
      end
    end

    context "when the import file upload does not exist" do
      let(:import_file_upload) { nil }

      it_behaves_like "ReportController#import_widgets"

      it "returns the flash message" do
        xhr :post, :import_widgets, params
        response.body.should == [{:message => "Error: Widget import file upload expired", :level => :error}].to_json
      end
    end
  end

  context "#report_selection_menus" do
    before do
      menu = [
        ["Trending", ["Hosts", ["Report 1", "Report 2"]]]
      ]
      controller.instance_variable_set(:@menu, menu)
      controller.instance_variable_set(:@edit,
                                       :new => {
                                         :filter    => "Trending",
                                         :subfilter => "Hosts"
                                       }
                                      )
      report1 = active_record_instance_double("MiqReport",
                                              :name => 'Report 1',
                                              :id   => 1,
                                              :db   => 'VimPerformanceTrend')
      report2 = active_record_instance_double("MiqReport",
                                              :name => 'Report 2',
                                              :id   => 2,
                                              :db   => 'VimPerformanceTrend')

      MiqReport.should_receive(:where).and_return([report1, report2])
    end

    it "Verify that Trending reports are excluded in widgets editor" do
      controller.instance_variable_set(:@sb, :active_tree => :widgets_tree)
      controller.send(:report_selection_menus)
      assigns(:reps).should eq([])
    end

    it "Verify that Trending reports are included in schedule menus editor" do
      controller.instance_variable_set(:@sb, :active_tree => :schedules_tree)
      controller.send(:report_selection_menus)
      assigns(:reps).count.should eq(2)
      assigns(:reps).should eq([["Report 1", 1], ["Report 2", 2]])
    end
  end
end

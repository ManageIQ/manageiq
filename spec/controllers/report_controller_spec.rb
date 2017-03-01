require "helpers/report_helper_spec"

describe ReportController do
  context "Get form variables" do
    context "press col buttons" do
      it "moves columns left" do
        controller.instance_variable_set(:@_params, :button => "left")
        expect(controller).to receive(:move_cols_left)
        controller.send(:gfv_move_cols_buttons)
      end

      it "moves columns right" do
        controller.instance_variable_set(:@_params, :button => "right")
        expect(controller).to receive(:move_cols_right)
        controller.send(:gfv_move_cols_buttons)
      end

      it "moves columns up" do
        controller.instance_variable_set(:@_params, :button => "up")
        expect(controller).to receive(:move_cols_up)
        controller.send(:gfv_move_cols_buttons)
      end

      it "moves columns down" do
        controller.instance_variable_set(:@_params, :button => "down")
        expect(controller).to receive(:move_cols_down)
        controller.send(:gfv_move_cols_buttons)
      end

      it "moves columns top" do
        controller.instance_variable_set(:@_params, :button => "top")
        expect(controller).to receive(:move_cols_top)
        controller.send(:gfv_move_cols_buttons)
      end

      it "moves columns bottom" do
        controller.instance_variable_set(:@_params, :button => "bottom")
        expect(controller).to receive(:move_cols_bottom)
        controller.send(:gfv_move_cols_buttons)
      end
    end

    context "handle input fields" do
      before :each do
        controller.instance_variable_set(:@edit, {:new => {}})  # Editor methods need @edit[:new]
        allow(controller).to receive(:build_edit_screen) # Don't actually build the edit screen
      end

      describe "#add_field_to_col_order" do
        let(:miq_report)               { FactoryGirl.create(:miq_report, :cols => [], :col_order => []) }
        let(:base_model)               { "Vm" }
        let(:virtual_custom_attribute) { "virtual_custom_attribute_kubernetes.io/hostname" }

        before do
          @edit = assigns(:edit)
          @edit[:new][:sortby1] = S1 # Set an initial sort by col
          @edit[:new][:sortby2] = S2 # Set no second sort col
          @edit[:new][:pivot] = ReportController::PivotOptions.new
          controller.instance_variable_set(:@edit, @edit)
        end

        it "fills report by passed column" do
          controller.send(:add_field_to_col_order, miq_report, "#{base_model}-#{virtual_custom_attribute}")
          expect(miq_report.cols.first).to eq(virtual_custom_attribute)
        end
      end

      context "handle report fields" do
        it "sets pdf page size" do
          ps = "US-Legal"
          controller.instance_variable_set(:@_params, :pdf_page_size => ps)
          controller.send(:gfv_report_fields)
          expect(assigns(:edit)[:new][:pdf_page_size]).to eq(ps)
        end

        it "sets queue timeout" do
          to = "1"
          controller.instance_variable_set(:@_params, {:chosen_queue_timeout => to})
          controller.send(:gfv_report_fields)
          expect(assigns(:edit)[:new][:queue_timeout]).to eq(to.to_i)
        end

        it "clears queue timeout" do
          to = ""
          controller.instance_variable_set(:@_params, {:chosen_queue_timeout => to})
          controller.send(:gfv_report_fields)
          expect(assigns(:edit)[:new][:queue_timeout]).to be_nil
        end

        it "sets row limit" do
          rl = "10"
          controller.instance_variable_set(:@_params, :row_limit => rl)
          controller.send(:gfv_report_fields)
          expect(assigns(:edit)[:new][:row_limit]).to eq(rl)
        end

        it "clears row limit" do
          rl = ""
          controller.instance_variable_set(:@_params, :row_limit => rl)
          controller.send(:gfv_report_fields)
          expect(assigns(:edit)[:new][:row_limit]).to eq("")
        end

        it "sets report name" do
          rn = "Report Name"
          controller.instance_variable_set(:@_params, :name => rn)
          controller.send(:gfv_report_fields)
          expect(assigns(:edit)[:new][:name]).to eq(rn)
        end

        it "sets report title" do
          rt = "Report Title"
          controller.instance_variable_set(:@_params, :title => rt)
          controller.send(:gfv_report_fields)
          expect(assigns(:edit)[:new][:title]).to eq(rt)
        end
      end

      context "handle model changes" do
        it "sets CI model" do
          model = "Vm"
          controller.instance_variable_set(:@_params, :chosen_model => model)
          controller.send(:gfv_model)
          expect(assigns(:edit)[:new][:model]).to eq(model)
          expect(assigns(:refresh_div)).to eq("form_div")
          expect(assigns(:refresh_partial)).to eq("form")
        end

        it "sets performance model" do
          model = "VmPerformance"
          controller.instance_variable_set(:@_params, :chosen_model => model)
          controller.send(:gfv_model)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:model]).to eq(model)
          expect(edit_new[:perf_interval]).to eq("daily")
          expect(edit_new[:perf_avgs]).to eq("time_interval")
          expect(edit_new[:tz]).to eq(session[:user_tz])
          expect(assigns(:edit)[:start_array]).to be_an_instance_of(Array)
          expect(assigns(:edit)[:end_array]).to be_an_instance_of(Array)
          expect(assigns(:refresh_div)).to eq("form_div")
          expect(assigns(:refresh_partial)).to eq("form")
        end

        it "sets chargeback model" do
          model = "ChargebackVm"
          controller.instance_variable_set(:@_params, :chosen_model => model)
          controller.send(:gfv_model)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:model]).to eq(model)
          expect(edit_new[:cb_interval]).to eq("daily")
          expect(edit_new[:cb_interval_size]).to eq(1)
          expect(edit_new[:cb_end_interval_offset]).to eq(1)
          expect(edit_new[:cb_groupby]).to eq("date")
          expect(edit_new[:tz]).to eq(session[:user_tz])
          expect(assigns(:refresh_div)).to eq("form_div")
          expect(assigns(:refresh_partial)).to eq("form")
        end
      end

      context "handle trend field changes" do
        it "sets trend column (non % based)" do
          tc = "VmPerformance-derived_memory_used"
          allow(MiqExpression).to receive(:reporting_available_fields)
            .and_return([["Test", tc]]) # Hand back array of arrays
          controller.instance_variable_set(:@_params, :chosen_trend_col => tc)
          controller.send(:gfv_trend)
          edit = assigns(:edit)
          edit_new = edit[:new]
          expect(edit_new[:perf_trend_db]).to eq(tc.split("-").first)
          expect(edit_new[:perf_trend_col]).to eq(tc.split("-").last)
          expect(edit_new[:perf_interval]).to eq("daily")
          expect(edit_new[:perf_target_pct1]).to eq(100)
          expect(edit_new[:perf_limit_val]).to be_nil
          expect(edit[:percent_col]).to be_falsey
          expect(edit[:start_array]).to be_an_instance_of(Array)
          expect(edit[:end_array]).to be_an_instance_of(Array)
          expect(assigns(:refresh_div)).to eq("columns_div")
          expect(assigns(:refresh_partial)).to eq("form_columns")
        end

        it "sets trend column (% based)" do
          tc = "VmPerformance-derived_memory_used"
          allow(MiqExpression).to receive(:reporting_available_fields)
            .and_return([["Test (%)", tc]]) # Hand back array of arrays
          controller.instance_variable_set(:@_params, :chosen_trend_col => tc)
          controller.send(:gfv_trend)
          edit = assigns(:edit)
          edit_new = edit[:new]
          expect(edit_new[:perf_trend_db]).to eq(tc.split("-").first)
          expect(edit_new[:perf_trend_col]).to eq(tc.split("-").last)
          expect(edit_new[:perf_interval]).to eq("daily")
          expect(edit_new[:perf_target_pct1]).to eq(100)
          expect(edit_new[:perf_limit_val]).to eq(100)
          expect(edit_new[:perf_limit_col]).to be_nil
          expect(edit[:percent_col]).to be_truthy
          expect(edit[:start_array]).to be_an_instance_of(Array)
          expect(edit[:end_array]).to be_an_instance_of(Array)
          expect(assigns(:refresh_div)).to eq("columns_div")
          expect(assigns(:refresh_partial)).to eq("form_columns")
        end

        it "clears trend column" do
          tc = "<Choose>"
          controller.instance_variable_set(:@_params, :chosen_trend_col => tc)
          controller.send(:gfv_trend)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:perf_trend_db]).to be_nil
          expect(edit_new[:perf_trend_col]).to be_nil
          expect(edit_new[:perf_interval]).to eq("daily")
          expect(edit_new[:perf_target_pct1]).to eq(100)
          expect(assigns(:refresh_div)).to eq("columns_div")
          expect(assigns(:refresh_partial)).to eq("form_columns")
        end

        it "sets trend limit column" do
          limit_col = "max_derived_cpu_reserved"
          controller.instance_variable_set(:@_params, :chosen_limit_col => limit_col)
          controller.send(:gfv_trend)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:perf_limit_col]).to eq(limit_col)
          expect(edit_new[:perf_limit_val]).to be_nil
          expect(assigns(:refresh_div)).to eq("columns_div")
          expect(assigns(:refresh_partial)).to eq("form_columns")
        end

        it "clears trend limit column" do
          limit_col = "<None>"
          controller.instance_variable_set(:@_params, :chosen_limit_col => limit_col)
          controller.send(:gfv_trend)
          expect(assigns(:edit)[:new][:perf_limit_col]).to be_nil
          expect(assigns(:refresh_div)).to eq("columns_div")
          expect(assigns(:refresh_partial)).to eq("form_columns")
        end

        it "sets trend limit value" do
          limit_val = "50"
          controller.instance_variable_set(:@_params, :chosen_limit_val => limit_val)
          controller.send(:gfv_trend)
          expect(assigns(:edit)[:new][:perf_limit_val]).to eq(limit_val)
        end

        it "sets trend limit percent 1" do
          pct = "70"
          controller.instance_variable_set(:@_params, :percent1 => pct)
          controller.send(:gfv_trend)
          expect(assigns(:edit)[:new][:perf_target_pct1]).to eq(pct.to_i)
        end

        it "sets trend limit percent 2" do
          pct = "80"
          controller.instance_variable_set(:@_params, :percent2 => pct)
          controller.send(:gfv_trend)
          expect(assigns(:edit)[:new][:perf_target_pct2]).to eq(pct.to_i)
        end

        it "sets trend limit percent 3" do
          pct = "90"
          controller.instance_variable_set(:@_params, :percent3 => pct)
          controller.send(:gfv_trend)
          expect(assigns(:edit)[:new][:perf_target_pct3]).to eq(pct.to_i)
        end
      end

      context "handle performance field changes" do
        it "sets perf interval" do
          perf_int = "hourly"
          controller.instance_variable_set(:@_params, {:chosen_interval => perf_int})
          controller.send(:gfv_performance)
          edit = assigns(:edit)
          edit_new = edit[:new]
          expect(edit_new[:perf_interval]).to eq(perf_int)
          expect(edit_new[:perf_start]).to eq(1.day.to_s)
          expect(edit_new[:perf_end]).to eq("0")
          expect(edit[:start_array]).to be_an_instance_of(Array)
          expect(edit[:end_array]).to be_an_instance_of(Array)
          expect(assigns(:refresh_div)).to eq("form_div")
          expect(assigns(:refresh_partial)).to eq("form")
        end

        it "sets perf averages" do
          perf_avg = "active_data"
          controller.instance_variable_set(:@_params, :perf_avgs => perf_avg)
          controller.send(:gfv_performance)
          expect(assigns(:edit)[:new][:perf_avgs]).to eq(perf_avg)
        end

        it "sets perf start" do
          perf_start = 3.days.to_s
          controller.instance_variable_set(:@_params, {:chosen_start => perf_start})
          controller.send(:gfv_performance)
          expect(assigns(:edit)[:new][:perf_start]).to eq(perf_start)
        end

        it "sets perf end" do
          perf_end = 1.days.to_s
          controller.instance_variable_set(:@_params, :chosen_end => perf_end)
          controller.send(:gfv_performance)
          expect(assigns(:edit)[:new][:perf_end]).to eq(perf_end)
        end

        it "sets perf time zone" do
          tz = "Pacific Time (US & Canada)"
          controller.instance_variable_set(:@_params, :chosen_tz => tz)
          controller.send(:gfv_performance)
          expect(assigns(:edit)[:new][:tz]).to eq(tz)
        end

        it "sets perf time profile" do
          time_prof = FactoryGirl.create(:time_profile, :description => "Test", :profile => {:tz => "UTC"})
          chosen_time_prof = time_prof.id.to_s
          controller.instance_variable_set(:@_params, :chosen_time_profile => chosen_time_prof)
          controller.send(:gfv_performance)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:time_profile]).to eq(chosen_time_prof.to_i)
        end

        it "clears perf time profile" do
          chosen_time_prof = ""
          controller.instance_variable_set(:@_params, :chosen_time_profile => chosen_time_prof)
          controller.send(:gfv_performance)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:time_profile]).to be_nil
          expect(edit_new[:time_profile_tz]).to be_nil
          expect(assigns(:refresh_div)).to eq("filter_div")
          expect(assigns(:refresh_partial)).to eq("form_filter")
        end
      end

      context "handle chargeback field changes" do
        it "sets show costs" do
          show_type = "owner"
          controller.instance_variable_set(:@_params, :cb_show_typ => show_type)
          controller.send(:gfv_chargeback)
          expect(assigns(:edit)[:new][:cb_show_typ]).to eq(show_type)
          expect(assigns(:refresh_div)).to eq("filter_div")
          expect(assigns(:refresh_partial)).to eq("form_filter")
        end

        it "clears show costs" do
          show_type = ""
          controller.instance_variable_set(:@_params, :cb_show_typ => show_type)
          controller.send(:gfv_chargeback)
          expect(assigns(:edit)[:new][:cb_show_typ]).to be_nil
          expect(assigns(:refresh_div)).to eq("filter_div")
          expect(assigns(:refresh_partial)).to eq("form_filter")
        end

        it "sets tag category" do
          tag_cat = "department"
          controller.instance_variable_set(:@_params, :cb_tag_cat => tag_cat)
          cl_rec = FactoryGirl.create(:classification, :name => "test_name", :description => "Test Description")
          expect(Classification).to receive(:find_by_name).and_return([cl_rec])
          controller.send(:gfv_chargeback)
          expect(assigns(:edit)[:new][:cb_tag_cat]).to eq(tag_cat)
          expect(assigns(:edit)[:cb_tags]).to be_a_kind_of(Hash)
          expect(assigns(:refresh_div)).to eq("filter_div")
          expect(assigns(:refresh_partial)).to eq("form_filter")
        end

        it "clears tag category" do
          tag_cat = ""
          controller.instance_variable_set(:@_params, :cb_tag_cat => tag_cat)
          controller.send(:gfv_chargeback)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:cb_tag_cat]).to be_nil
          expect(edit_new[:cb_tag_value]).to be_nil
          expect(assigns(:refresh_div)).to eq("filter_div")
          expect(assigns(:refresh_partial)).to eq("form_filter")
        end

        it "sets owner id" do
          owner_id = "admin"
          controller.instance_variable_set(:@_params, {:cb_owner_id => owner_id})
          controller.send(:gfv_chargeback)
          expect(assigns(:edit)[:new][:cb_owner_id]).to eq(owner_id)
        end

        it "sets tag value" do
          tag_val = "accounting"
          controller.instance_variable_set(:@_params, {:cb_tag_value => tag_val})
          controller.send(:gfv_chargeback)
          expect(assigns(:edit)[:new][:cb_tag_value]).to eq(tag_val)
        end

        it "sets group by" do
          group_by = "vm"
          controller.instance_variable_set(:@_params, :cb_groupby => group_by)
          controller.send(:gfv_chargeback)
          expect(assigns(:edit)[:new][:cb_groupby]).to eq(group_by)
        end

        it "sets show costs by" do
          show_costs_by = "day"
          controller.instance_variable_set(:@_params, {:cb_interval => show_costs_by})
          controller.send(:gfv_chargeback)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:cb_interval]).to eq(show_costs_by)
          expect(edit_new[:cb_interval_size]).to eq(1)
          expect(edit_new[:cb_end_interval_offset]).to eq(1)
          expect(assigns(:refresh_div)).to eq("filter_div")
          expect(assigns(:refresh_partial)).to eq("form_filter")
        end

        it "sets interval size" do
          int_size = "2"
          controller.instance_variable_set(:@_params, {:cb_interval_size => int_size})
          controller.send(:gfv_chargeback)
          expect(assigns(:edit)[:new][:cb_interval_size]).to eq(int_size.to_i)
        end

        it "sets end interval offset" do
          end_int_offset = "2"
          controller.instance_variable_set(:@_params, :cb_end_interval_offset => end_int_offset)
          controller.send(:gfv_chargeback)
          expect(assigns(:edit)[:new][:cb_end_interval_offset]).to eq(end_int_offset.to_i)
        end
      end

      context "handle chart field changes" do
        it "sets chart type" do
          chosen_graph = "Bar"
          controller.instance_variable_set(:@_params, {:chosen_graph => chosen_graph})
          controller.send(:gfv_charts)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:graph_type]).to eq(chosen_graph)
          expect(edit_new[:graph_other]).to be_truthy
          expect(edit_new[:graph_count]).to eq(GRAPH_MAX_COUNT)
          expect(assigns(:refresh_div)).to eq("chart_div")
          expect(assigns(:refresh_partial)).to eq("form_chart")
        end

        it "clears chart type" do
          chosen_graph = "<No chart>"
          controller.instance_variable_set(:@_params, {:chosen_graph => chosen_graph})
          edit = assigns(:edit)
          edit[:current] = {:graph_count => GRAPH_MAX_COUNT, :graph_other => true}
          controller.instance_variable_set(:@edit, edit)
          controller.send(:gfv_charts)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:graph_type]).to be_nil
          expect(edit_new[:graph_other]).to be_truthy
          expect(edit_new[:graph_count]).to eq(GRAPH_MAX_COUNT)
          expect(assigns(:refresh_div)).to eq("chart_div")
          expect(assigns(:refresh_partial)).to eq("form_chart")
        end

        it "sets top values to show" do
          top_val = "3"
          controller.instance_variable_set(:@_params, {:chosen_count => top_val})
          controller.send(:gfv_charts)
          expect(assigns(:edit)[:new][:graph_count]).to eq(top_val)
          expect(assigns(:refresh_div)).to eq("chart_sample_div")
          expect(assigns(:refresh_partial)).to eq("form_chart_sample")
        end

        it "sets sum other values" do
          sum_other = "null"
          controller.instance_variable_set(:@_params, :chosen_other => sum_other)
          controller.send(:gfv_charts)
          expect(assigns(:edit)[:new][:graph_other]).to be_falsey
          expect(assigns(:refresh_div)).to eq("chart_sample_div")
          expect(assigns(:refresh_partial)).to eq("form_chart_sample")
        end
      end

      context "handle consolidation field changes" do
        P1 = "Vm-name"
        P2 = "Vm-boot_time"
        P3 = "Vm-hostname"
        before :each do
          edit = assigns(:edit)
          edit[:pivot_cols] = {}
          controller.instance_variable_set(:@edit, edit)
          expect(controller).to receive(:build_field_order).once
        end

        it "sets pivot 1" do
          controller.instance_variable_set(:@_params, :chosen_pivot1 => P1)
          controller.send(:gfv_pivots)
          expect(assigns(:edit)[:new][:pivot].by1).to eq(P1)
          expect(assigns(:refresh_div)).to eq("consolidate_div")
          expect(assigns(:refresh_partial)).to eq("form_consolidate")
        end

        it "sets pivot 2" do
          controller.instance_variable_set(:@_params, :chosen_pivot2 => P2)
          controller.send(:gfv_pivots)
          expect(assigns(:edit)[:new][:pivot].by2).to eq(P2)
          expect(assigns(:refresh_div)).to eq("consolidate_div")
          expect(assigns(:refresh_partial)).to eq("form_consolidate")
        end

        it "sets pivot 3" do
          controller.instance_variable_set(:@_params, :chosen_pivot3 => P3)
          controller.send(:gfv_pivots)
          expect(assigns(:edit)[:new][:pivot].by3).to eq(P3)
          expect(assigns(:refresh_div)).to eq("consolidate_div")
          expect(assigns(:refresh_partial)).to eq("form_consolidate")
        end

        it "clearing pivot 1 also clears pivot 2 and 3" do
          edit = assigns(:edit)
          edit[:new][:pivot] = ReportController::PivotOptions.new(P1, P2, P3)
          controller.instance_variable_set(:@edit, edit)
          controller.instance_variable_set(:@_params, :chosen_pivot1 => NOTHING_STRING)
          controller.send(:gfv_pivots)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:pivot].by1).to eq(NOTHING_STRING)
          expect(edit_new[:pivot].by2).to eq(NOTHING_STRING)
          expect(edit_new[:pivot].by3).to eq(NOTHING_STRING)
          expect(assigns(:refresh_div)).to eq("consolidate_div")
          expect(assigns(:refresh_partial)).to eq("form_consolidate")
        end

        it "clearing pivot 2 also clears pivot 3" do
          edit = assigns(:edit)
          edit[:new][:pivot] = ReportController::PivotOptions.new(P1, P2, P3)
          controller.instance_variable_set(:@edit, edit)
          controller.instance_variable_set(:@_params, :chosen_pivot2 => NOTHING_STRING)
          controller.send(:gfv_pivots)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:pivot].by1).to eq(P1)
          expect(edit_new[:pivot].by2).to eq(NOTHING_STRING)
          expect(edit_new[:pivot].by3).to eq(NOTHING_STRING)
          expect(assigns(:refresh_div)).to eq("consolidate_div")
          expect(assigns(:refresh_partial)).to eq("form_consolidate")
        end

        it "setting pivot 1 = pivot 2 bubbles up pivot 3 to 2" do
          edit = assigns(:edit)
          edit[:new][:pivot] = ReportController::PivotOptions.new(P1, P2, P3)
          controller.instance_variable_set(:@edit, edit)
          controller.instance_variable_set(:@_params, :chosen_pivot1 => P2)
          controller.send(:gfv_pivots)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:pivot].by1).to eq(P2)
          expect(edit_new[:pivot].by2).to eq(P3)
          expect(edit_new[:pivot].by3).to eq(NOTHING_STRING)
          expect(assigns(:refresh_div)).to eq("consolidate_div")
          expect(assigns(:refresh_partial)).to eq("form_consolidate")
        end

        it "setting pivot 2 = pivot 3 clears pivot 3" do
          edit = assigns(:edit)
          edit[:new][:pivot] = ReportController::PivotOptions.new(P1, P2, P3)
          controller.instance_variable_set(:@edit, edit)
          controller.instance_variable_set(:@_params, :chosen_pivot2 => P3)
          controller.send(:gfv_pivots)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:pivot].by1).to eq(P1)
          expect(edit_new[:pivot].by2).to eq(P3)
          expect(edit_new[:pivot].by3).to eq(NOTHING_STRING)
          expect(assigns(:refresh_div)).to eq("consolidate_div")
          expect(assigns(:refresh_partial)).to eq("form_consolidate")
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
          edit[:new][:col_options] = {}     # Create col_options hash so keys can be set
          edit[:new][:field_order] = []    # Create field_order array
          controller.instance_variable_set(:@edit, edit)
        end

        it "sets first sort col" do
          new_sort = "Vm-new"
          controller.instance_variable_set(:@_params, :chosen_sort1 => new_sort)
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:sortby1]).to eq(new_sort)
          expect(edit_new[:sortby2]).to eq(S2)
          expect(assigns(:refresh_div)).to eq("sort_div")
          expect(assigns(:refresh_partial)).to eq("form_sort")
        end

        it "set first sort col = second clears second" do
          controller.instance_variable_set(:@_params, :chosen_sort1 => S2)
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:sortby1]).to eq(S2)
          expect(edit_new[:sortby2]).to eq(NOTHING_STRING)
          expect(assigns(:refresh_div)).to eq("sort_div")
          expect(assigns(:refresh_partial)).to eq("form_sort")
        end

        it "clearing first sort col clears both sort cols" do
          controller.instance_variable_set(:@_params, :chosen_sort1 => NOTHING_STRING)
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:sortby1]).to eq(NOTHING_STRING)
          expect(edit_new[:sortby2]).to eq(NOTHING_STRING)
          expect(assigns(:refresh_div)).to eq("sort_div")
          expect(assigns(:refresh_partial)).to eq("form_sort")
        end

        it "sets first sort col suffix" do
          sfx = "hour"
          controller.instance_variable_set(:@_params, :sort1_suffix => sfx)
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:sortby1]).to eq("#{S1}__#{sfx}")
          expect(edit_new[:sortby2]).to eq(S2)
        end

        it "sets sort order" do
          sort_order = "Descending"
          controller.instance_variable_set(:@_params, :sort_order => sort_order)
          controller.send(:gfv_sort)
          expect(assigns(:edit)[:new][:order]).to eq(sort_order)
        end

        it "sets sort breaks" do
          sort_group = "Yes"
          controller.instance_variable_set(:@_params, :sort_group => sort_group)
          controller.send(:gfv_sort)
          expect(assigns(:edit)[:new][:group]).to eq(sort_group)
          expect(assigns(:refresh_div)).to eq("sort_div")
          expect(assigns(:refresh_partial)).to eq("form_sort")
        end

        it "sets hide detail rows" do
          hide_detail = "1"
          controller.instance_variable_set(:@_params, {:hide_details => hide_detail})
          controller.send(:gfv_sort)
          expect(assigns(:edit)[:new][:hide_details]).to be_truthy
        end

        # TODO: Not sure why, but this test seems to take .5 seconds while others are way faster
        it "sets format on summary row" do
          fmt = "hour_am_pm"
          controller.instance_variable_set(:@_params, :break_format => fmt)
          controller.send(:gfv_sort)

          # Check to make sure the proper value gets set in the col_options hash using the last part of the sortby1 col as key
          opts = assigns(:edit)[:new][:col_options]
          key = S1.split("-").last
          expect(opts[key]).to be_a_kind_of(Hash)
          expect(opts[key][:break_format]).to eq(fmt.to_sym)
        end

        it "sets second sort col" do
          new_sort = "Vm-new"
          controller.instance_variable_set(:@_params, :chosen_sort2 => new_sort)
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:sortby1]).to eq(S1)
          expect(edit_new[:sortby2]).to eq(new_sort)
        end

        it "clearing second sort col" do
          controller.instance_variable_set(:@_params, :chosen_sort2 => NOTHING_STRING)
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:sortby1]).to eq(S1)
          expect(edit_new[:sortby2]).to eq(NOTHING_STRING)
        end

        it "sets second sort col suffix" do
          sfx = "day"
          controller.instance_variable_set(:@_params, :sort2_suffix => sfx)
          controller.send(:gfv_sort)
          edit_new = assigns(:edit)[:new]
          expect(edit_new[:sortby1]).to eq(S1)
          expect(edit_new[:sortby2]).to eq("#{S2}__#{sfx}")
        end

        it 'grouping value is a sorted array of symbols' do
          edit_new = assigns(:edit)[:new]
          edit_new[:field_order] = [['Vm-foobar']]
          controller.send(:gfv_key_group_calculations, 'foobar_0', 'total,avg')
          expect(edit_new[:col_options]['foobar'][:grouping]).to eq([:avg, :total])
        end

        it 'aggregs are stored under pivot_cols as a sorted array of symbols' do
          edit = assigns(:edit)
          edit[:pivot_cols] = {}
          edit[:new][:fields] = [[name = 'Vm-foobar']]
          edit[:new][:headers] = {name => 'shoot me now!'}
          controller.send(:gfv_key_pivot_calculations, 'foobar_0', 'total,avg')
          expect(edit[:pivot_cols][name]).to eq([:avg, :total])
        end
      end

      context "handle timeline field changes" do
        before :each do
          col = "Vm-created_on"
          controller.instance_variable_set(:@_params, :chosen_tl => col)
          controller.send(:gfv_timeline)  # This will set the @edit timeline unit hash keys
        end

        it "sets timeline col" do
          col = "Vm-boot_time"
          controller.instance_variable_set(:@_params, :chosen_tl => col)
          controller.send(:gfv_timeline)
          expect(assigns(:edit)[:new][:tl_field]).to eq(col)
        end

        it "clears timeline col" do
          controller.instance_variable_set(:@_params, {:chosen_tl => NOTHING_STRING})
          controller.send(:gfv_timeline)
          edit = assigns(:edit)
          expect(edit[:new][:tl_field]).to eq(NOTHING_STRING)
        end

        it "sets event to position at" do
          pos = "First"
          controller.instance_variable_set(:@_params, :chosen_position => pos)
          controller.send(:gfv_timeline)
          expect(assigns(:edit)[:new][:tl_position]).to eq(pos)
          expect(assigns(:tl_changed)).to be_truthy
        end

      end
    end
  end

  context "ReportController::Schedules" do
    let(:miq_report) { FactoryGirl.create(:miq_report) }

    before do
      @current_user = login_as FactoryGirl.create(:user, :features => %w(miq_report_schedule_enable
                                                                         miq_report_schedule_disable
                                                                         miq_report_schedule_edit))
    end

    context "no schedules selected" do
      before do
        allow(controller).to receive(:find_checked_items).and_return([])
        expect(controller).to receive(:render)
        expect(controller).to receive(:schedule_get_all)
        expect(controller).to receive(:replace_right_cell)
      end

      it "#miq_report_schedule_enable" do
        controller.miq_report_schedule_enable
        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to eq("No Report Schedules were selected to be enabled")
        expect(flash_messages.first[:level]).to eq(:error)
      end

      it "#miq_report_schedule_disable" do
        controller.miq_report_schedule_disable
        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to eq("No Report Schedules were selected to be disabled")
        expect(flash_messages.first[:level]).to eq(:error)
      end
    end

    context "normal case" do
      before do
        server = double
        allow(server).to receive_messages(:zone_id => 1)
        allow(MiqServer).to receive(:my_server).and_return(server)

        @sch = FactoryGirl.create(:miq_schedule, :enabled => true, :updated_at => 1.hour.ago.utc)

        allow(controller).to receive(:find_checked_items).and_return([@sch])
        expect(controller).to receive(:render).never
        expect(controller).to receive(:schedule_get_all)
        expect(controller).to receive(:replace_right_cell)
      end

      it "#miq_report_schedule_enable" do
        @sch.update_attribute(:enabled, false)

        controller.miq_report_schedule_enable
        expect(controller.send(:flash_errors?)).not_to be_truthy
        @sch.reload
        expect(@sch).to be_enabled
        expect(@sch.updated_at).to be > 10.minutes.ago.utc
      end

      it "#miq_report_schedule_disable" do
        controller.miq_report_schedule_disable
        expect(controller.send(:flash_errors?)).not_to be_truthy
        @sch.reload
        expect(@sch).not_to be_enabled
        expect(@sch.updated_at).to be > 10.minutes.ago.utc
      end

      it "contains current group id in sched_action field" do
        controller.instance_variable_set(:@_params, :button => "add", :controller => "report",
                                                    :action => "schedule_edit")
        controller.miq_report_schedule_disable
        allow(controller).to receive_messages(:load_edit => true)
        allow(controller).to receive(:replace_right_cell)
        timer = ReportHelper::Timer.new('Once', 1, 1, 1, 1, '12/04/2015', '00', '00')
        controller.instance_variable_set(:@edit,
                                         :sched_id => nil, :new => {:name => "test_1", :description => "test_1",
                                                                    :enabled => true, :send_email => false,
                                                                    :email => {:send_if_empty => true},
                                                                    :timer => timer,
                                                                    :filter => "Configuration Management",
                                                                    :subfilter => "Virtual Machines",
                                                                    :repfilter => miq_report.id},
                                         :key => "schedule_edit__new")
        controller.instance_variable_set(:@sb, :trees => {:schedules_tree => {:schedules_tree => "root"}})
        controller.send(:schedule_edit)
        miq_schedule = MiqSchedule.find_by(:name => "test_1")
        expect(miq_schedule.sched_action).to be_kind_of(Hash)
        expect(miq_schedule.sched_action[:method]).to eq("run_report")
        expect(miq_schedule.sched_action[:options]).to be_kind_of(Hash)
        expect(miq_schedule.sched_action[:options][:miq_group_id]).to eq(@current_user.current_group.id)
      end
    end
  end

  describe 'x_button' do
    before(:each) do
      stub_user(:features => :all)
      ApplicationController.handle_exceptions = true
    end

    describe 'corresponding methods are called for allowed actions' do
      ReportController::REPORT_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
        it "calls the appropriate method: '#{method}' for action '#{action_name}'" do
          expect(controller).to receive(method)
          get :x_button, :params => { :pressed => action_name }
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :params => { :pressed => 'random_dude', :format => :html }
      expect(response).to render_template('layouts/exception')
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
      let(:widgets) { [double("MiqWidget")] }

      before do
        records = widgets
        allow(MiqWidget).to receive(:where).with(:id => widget_list).and_return(records)
        allow(MiqWidget).to receive(:export_to_yaml).with(widgets, MiqWidget).and_return(widget_yaml)
      end

      it "sends the data" do
        get :export_widgets, :params => params
        expect(response.body).to eq("the widget yaml")
      end

      it "sets the filename to the current date" do
        Timecop.freeze(2013, 1, 2) do
          get :export_widgets, :params => params
          expect(response.header['Content-Disposition']).to include("widget_export_20130102_000000.yml")
        end
      end
    end

    context "when there are not widget parameters" do
      let(:widget_list) { nil }

      it "sets a flash message" do
        get :export_widgets, :params => params
        expect(assigns(:flash_array))
          .to eq([{:message => "At least 1 item must be selected for export",
                   :level   => :error}])
      end

      it "sets the flash array on the sandbox" do
        get :export_widgets, :params => params
        expect(assigns(:sb)[:flash_msg])
          .to eq([{:message => "At least 1 item must be selected for export",
                   :level   => :error}])
      end

      it "redirects to the explorer" do
        get :export_widgets, :params => params
        expect(response).to redirect_to(:action => :explorer)
      end
    end
  end

  describe "#upload_widget_import_file" do
    include_context "valid session"

    let(:widget_import_service) { double("WidgetImportService") }

    before do
      bypass_rescue
      allow(controller).to receive(:x_node) { 'xx-exportwidgets' }
      controller.instance_variable_set(:@in_a_form, true)
    end

    shared_examples_for "ReportController#upload_widget_import_file that does not upload a file" do
      it "returns with a warning message" do
        post :upload_widget_import_file, :params => params, :xhr => true
        expect(controller.instance_variable_get(:@flash_array))
          .to include(:message => "Use the Choose file button to locate an import file", :level => :warning)
      end
    end

    context "when an upload file is given" do
      let(:filename) { "filename" }
      let(:file) { fixture_file_upload("files/dummy_file.yml", "text/yml") }
      let(:params) { {:upload => {:file => file}} }

      before do
        allow(WidgetImportService).to receive(:new).and_return(widget_import_service)
        login_as(FactoryGirl.create(:user))
      end

      context "when the widget importer does not raise an error" do
        let(:ret) { FactoryGirl.build_stubbed(:import_file_upload, :id => '123') }

        before do
          allow(ret).to receive(:widget_list).and_return([])
          allow(widget_import_service).to receive(:store_for_import).with("the yaml data\n").and_return(ret)
        end

        it "returns with an import file upload id" do
          post :upload_widget_import_file, :params => params, :xhr => true
          expect(controller.instance_variable_get(:@flash_array))
            .to include(:message => "Import file was uploaded successfully", :level => :success)
          expect(controller.instance_variable_get(:@import_file_upload_id)).to eq(123)
        end

        it "imports the widgets" do
          expect(widget_import_service).to receive(:store_for_import).with("the yaml data\n")
          post :upload_widget_import_file, :params => params, :xhr => true
        end
      end

      context "when the widget importer raises an import error" do
        before do
          allow(widget_import_service).to receive(:store_for_import).and_raise(WidgetImportValidator::NonYamlError)
        end

        it "returns with an error message" do
          post :upload_widget_import_file, :params => params, :xhr => true
          expect(controller.instance_variable_get(:@flash_array))
            .to include(:message => "Error: the file uploaded is not of the supported format", :level => :error)
        end
      end

      context "when the widget importer raises a non valid widget yaml error" do
        before do
          allow(widget_import_service).to receive(:store_for_import)
            .and_raise(WidgetImportValidator::InvalidWidgetYamlError)
        end

        it "returns with an error message" do
          post :upload_widget_import_file, :params => params, :xhr => true
          expect(controller.instance_variable_get(:@flash_array))
            .to include(:message => "Error: the file uploaded contains no widgets", :level => :error)
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

  describe "#import_widgets" do
    include_context "valid session"

    let(:widget_import_service) { double("WidgetImportService") }

    before do
      bypass_rescue
      allow(controller).to receive(:x_node) { 'xx-exportwidgets' }
      controller.instance_variable_set(:@in_a_form, true)
    end

    context "when the commit button is used" do
      let(:params) { {:import_file_upload_id => "123", :widgets_to_import => ["potato"], :commit => _('Commit')} }

      before do
        allow(ImportFileUpload).to receive(:where).with(:id => "123").and_return([import_file_upload])
        allow(WidgetImportService).to receive(:new).and_return(widget_import_service)
      end

      shared_examples_for "ReportController#import_widgets" do
        it "returns a status of 200" do
          post :import_widgets, :params => params, :xhr => true
          expect(response.status).to eq(200)
        end
      end

      context "when the import file upload exists" do
        let(:import_file_upload) { double("ImportFileUpload") }

        before do
          allow(widget_import_service).to receive(:import_widgets)
        end

        it_behaves_like "ReportController#import_widgets"

        it "imports the data" do
          expect(widget_import_service).to receive(:import_widgets).with(import_file_upload, ["potato"])
          post :import_widgets, :params => params, :xhr => true
        end

        it "returns the flash message" do
          post :import_widgets, :params => params, :xhr => true
          expect(controller.instance_variable_get(:@flash_array))
            .to include(:message => "Widgets imported successfully", :level => :success)
        end
      end

      context "when the import file upload does not exist" do
        let(:import_file_upload) { nil }

        it_behaves_like "ReportController#import_widgets"

        it "returns the flash message" do
          post :import_widgets, :params => params, :xhr => true
          expect(controller.instance_variable_get(:@flash_array))
            .to include(:message => "Error: Widget import file upload expired", :level => :error)
        end
      end
    end

    context "when the cancel button is used" do
      let(:params) { {:import_file_upload_id => "123", :commit => _('Cancel')} }

      before do
        allow(WidgetImportService).to receive(:new).and_return(widget_import_service)
        allow(widget_import_service).to receive(:cancel_import)
      end

      it "cancels the import" do
        expect(widget_import_service).to receive(:cancel_import).with("123")
        post :import_widgets, :params => params, :xhr => true
      end

      it "returns a 200" do
        post :import_widgets, :params => params, :xhr => true
        expect(response.status).to eq(200)
      end

      it "returns the flash messages" do
        post :import_widgets, :params => params, :xhr => true
        expect(controller.instance_variable_get(:@flash_array))
          .to include(:message => "Widget import cancelled", :level => :info)
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
      report1 = double("MiqReport",
                                              :name => 'Report 1',
                                              :id   => 1,
                                              :db   => 'VimPerformanceTrend')
      report2 = double("MiqReport",
                                              :name => 'Report 2',
                                              :id   => 2,
                                              :db   => 'VimPerformanceTrend')

      expect(MiqReport).to receive(:where).and_return([report1, report2])
    end

    it "Verify that Trending reports are excluded in widgets editor" do
      controller.instance_variable_set(:@sb, :active_tree => :widgets_tree)
      controller.send(:report_selection_menus)
      expect(assigns(:reps)).to eq([])
    end

    it "Verify that Trending reports are included in schedule menus editor" do
      controller.instance_variable_set(:@sb, :active_tree => :schedules_tree)
      controller.send(:report_selection_menus)
      expect(assigns(:reps).count).to eq(2)
      expect(assigns(:reps)).to eq([["Report 1", 1], ["Report 2", 2]])
    end
  end

  context "#replace_right_cell" do
    before do
      FactoryGirl.create(:tenant, :parent => Tenant.root_tenant)
      login_as FactoryGirl.create(:user_admin) # not sure why this needs to be an admin...
    end

    it "should rebuild trees when last report result is newer than last tree build time" do
      controller.instance_variable_set(:@sb,
                                       :trees       => {:reports_tree => {:active_node => "root"}},
                                       :active_tree => :reports_tree)
      allow(controller).to receive(:x_node) { 'root' }
      allow(controller).to receive(:get_node_info)
      allow(controller).to receive(:x_build_dyna_tree)
      last_build_time = Time.now.utc
      controller.instance_variable_set(:@sb, :rep_tree_build_time => last_build_time)
      FactoryGirl.create(:miq_report_with_results)
      expect(controller).to receive(:build_savedreports_tree)
      expect(controller).to receive(:build_db_tree)
      expect(controller).to receive(:build_widgets_tree)
      expect(controller).to receive(:render)
      controller.send(:replace_right_cell)
    end

    it "should not rebuild trees when last report result is older than last tree build time" do
      FactoryGirl.create(:miq_report_with_results)
      controller.instance_variable_set(:@sb,
                                       :trees       => {:reports_tree => {:active_node => "root"}},
                                       :active_tree => :reports_tree)
      allow(controller).to receive(:x_node) { 'root' }
      allow(controller).to receive(:get_node_info)
      allow(controller).to receive(:x_build_dyna_tree)
      last_build_time = Time.now.utc
      controller.instance_variable_set(:@sb, :rep_tree_build_time => last_build_time)
      expect(controller).not_to receive(:build_report_listnav)
      expect(controller).not_to receive(:build_savedreports_tree)
      expect(controller).not_to receive(:build_db_tree)
      expect(controller).not_to receive(:build_widgets_tree)
      expect(controller).to receive(:render)
      controller.send(:replace_right_cell)
    end

    it "should rebuild trees reports tree when replace_trees is passed in" do
      # even tho rebuild_trees is false, it should still rebuild reports tree because
      # {:replace_trees => [:reports]} is passed in
      Tenant.seed
      FactoryGirl.create(:miq_report_with_results)
      controller.instance_variable_set(:@sb,
                                       :trees       => {:reports_tree => {:active_node => "root"}},
                                       :active_tree => :reports_tree)
      allow(controller).to receive(:x_node) { 'root' }
      allow(controller).to receive(:get_node_info)
      allow(controller).to receive(:x_build_dyna_tree)
      last_build_time = Time.now.utc
      controller.instance_variable_set(:@sb, :rep_tree_build_time => last_build_time)
      expect(controller).not_to receive(:build_savedreports_tree)
      expect(controller).not_to receive(:build_db_tree)
      expect(controller).not_to receive(:build_widgets_tree)
      expect(controller).to receive(:render)
      controller.send(:replace_right_cell, :replace_trees => [:reports])
    end
  end

  context "#rebuild_trees" do
    before do
      login_as FactoryGirl.create(:user_admin) # not sure why this needs to be an admin...
    end

    it "rebuild trees, latest report result was created after last time tree was built" do
      last_build_time = Time.now.utc
      controller.instance_variable_set(:@sb, :rep_tree_build_time => last_build_time)
      FactoryGirl.create(:miq_report_with_results)
      res = controller.send(:rebuild_trees)
      expect(res).to be(true)
      expect(assigns(:sb)[:rep_tree_build_time]).not_to eq(last_build_time)
    end

    it "don't rebuild trees, latest report result was created before last time tree was built" do
      FactoryGirl.create(:miq_report_with_results)
      last_build_time = Time.now.utc
      controller.instance_variable_set(:@sb, :rep_tree_build_time => last_build_time)
      res = controller.send(:rebuild_trees)
      expect(res).to be(false)
      expect(assigns(:sb)[:rep_tree_build_time]).to eq(last_build_time)
    end
  end

  describe "#get_all_saved_reports" do
    before do
      EvmSpecHelper.local_miq_server
    end

    context "User1 has Group1(current group: Group1), User2 has Group1, Group2(current group: Group2)" do
      before do
        EvmSpecHelper.local_miq_server

        MiqUserRole.seed
        role = MiqUserRole.find_by_name("EvmRole-operator")

        # User1 with 2 groups(Group1,Group2), current group for User2 is Group2
        create_user_with_group('User2', "Group1", role)

        @user1 = create_user_with_group('User1', "Group2", role)
        @user1.miq_groups << MiqGroup.where(:description => "Group1")
        login_as @user1
      end

      context "User2 generates report under Group1" do
        before :each do
          @rpt = create_and_generate_report_for_user("Vendor and Guest OS", "User2")
        end

        it "is allowed to see report created under Group1 for User 1(with current group Group2)" do
          controller.instance_variable_set(:@_params, :controller => "report", :action => "explorer")
          seed_session_trees('report', :saved_reports)
          allow(controller).to receive(:get_view_calculate_gtl_type).and_return("list")
          allow(controller).to receive(:get_view_pages_perpage).and_return(20)

          controller.send(:get_all_saved_reports)

          displayed_items = controller.instance_variable_get(:@pages)[:items]
          expect(displayed_items).to eq(1)

          expected_report_id = controller.instance_variable_get(:@view).table.data.last.miq_report_id
          expect(expected_report_id).to eq(@rpt.id)
        end

        it "is allowed to see miq report result for User1(with current group Group2)" do
          report_result_id = @rpt.miq_report_results.first.id
          controller.instance_variable_set(:@_params, :id => controller.to_cid(report_result_id),
                                                      :controller => "report", :action => "explorer")
          controller.instance_variable_set(:@sb, :last_savedreports_id => nil)
          allow(controller).to receive(:get_all_reps)
          controller.send(:show_saved_report)
          fetched_report_result = controller.instance_variable_get(:@report_result)
          expect(fetched_report_result.id).to eq(@rpt.miq_report_results.first.id)
          expect(fetched_report_result.miq_report.id).to eq(@rpt.id)
        end
      end
    end
  end

  describe "#reports_menu_in_sb" do
    let(:user) { FactoryGirl.create(:user_with_group) }
    subject! { FactoryGirl.create(:miq_report, :rpt_type => "Custom", :miq_group => user.current_group) }

    before do
      EvmSpecHelper.local_miq_server
      login_as user
    end

    it "it returns corrent name for custom folder" do
      controller.instance_variable_set(:@_params, :controller => "report", :action => "explorer")
      controller.instance_variable_set(:@sb, {})
      allow(controller).to receive(:get_node_info)
      controller.send(:reports_menu_in_sb)
      rpt_menu = controller.instance_variable_get(:@sb)[:rpt_menu]
      expect(rpt_menu.first.first).to eq("#{user.current_tenant.name} (EVM Group): #{user.current_group.name}")
    end
  end

  describe "#miq_report_edit" do
    let(:admin_user)   { FactoryGirl.create(:user, :role => "super_administrator") }
    let(:tenant)       { FactoryGirl.create(:tenant) }
    let(:chosen_model) { "ChargebackVm" }

    before do
      EvmSpecHelper.local_miq_server
      login_as admin_user
      allow(controller).to receive(:assert_privileges).and_return(true)
      allow(controller).to receive(:load_edit).and_return(true)
      allow(controller).to receive(:check_privileges).and_return(true)
      allow(controller).to receive(:x_node).and_return("root")
      allow(controller).to receive(:replace_right_cell).and_return(true)
    end

    it "adds new report based on ChargebackVm" do
      count_miq_reports = MiqReport.count

      post :x_button, :params => {:pressed => "miq_report_new"}
      post :form_field_changed, :params => {:id => "new", :chosen_model => chosen_model}
      post :form_field_changed, :params => {:id => "new", :title => "test"}
      post :form_field_changed, :params => {:id => "new", :name => "test"}
      post :form_field_changed, :params => {:button => "right", :available_fields => ["ChargebackVm-cpu_cost"]}
      post :form_field_changed, :params => {:id => "new", :cb_show_typ => "tenant"}
      post :form_field_changed, :params => {:id => "new", :cb_tenant_id => tenant.id}

      post :miq_report_edit, :params => {:button => "add"}

      expect(MiqReport.count).to eq(count_miq_reports + 1)
      expect(MiqReport.last.db_options[:rpt_type]).to eq(chosen_model)
      expect(MiqReport.last.db).to eq(chosen_model)
    end

    it "cb_entities_by_provider_id is set for chargeback based reports" do
      post :x_button, :params => {:pressed => "miq_report_new"}
      post :form_field_changed, :params => {:id => "new", :chosen_model => "ChargebackContainerImage"}
      post :form_field_changed, :params => {:id => "new", :title => "test"}
      post :form_field_changed, :params => {:id => "new", :name => "test"}
      post :form_field_changed, :params => {:button => "right", :available_fields => ["ChargebackContainerImage-archived"]}

      post :miq_report_edit, :params => {:button => "add"}
      expect(assigns(:cb_entities_by_provider_id)).not_to be_nil
    end

    it "cb_entities_by_provider_id is not set for not chargeback reports" do
      post :x_button, :params => {:pressed => "miq_report_new"}
      post :form_field_changed, :params => {:id => "new", :chosen_model => "Host"}
      post :form_field_changed, :params => {:id => "new", :title => "test"}
      post :form_field_changed, :params => {:id => "new", :name => "test"}
      post :form_field_changed, :params => {:button => "right", :available_fields => ["Host-name"]}

      post :miq_report_edit, :params => {:button => "add"}
      expect(assigns(:cb_entities_by_provider_id)).to be_nil
    end

    it 'allows user to remove columns while editing' do
      post :x_button, :params => {:pressed => 'miq_report_new'}
      post :form_field_changed, :params => {:id => 'new', :chosen_model => chosen_model}
      post :form_field_changed, :params => {:id => 'new', :title => 'test'}
      post :form_field_changed, :params => {:id => 'new', :name => 'test'}
      post :form_field_changed, :params => {:button => "right", :available_fields => ["ChargebackVm-cpu_cost"]}
      resp = post :form_field_changed, :params => {:button => "left", :selected_fields => ["ChargebackVm-cpu_cost"]}
      expect(resp.error?).to be_falsey
    end
  end
end

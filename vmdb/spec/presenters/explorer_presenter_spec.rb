require "spec_helper"

describe ExplorerPresenter do
  context "partial methods" do
    before :each do
      @presenter = ExplorerPresenter.new
      @presenter[:temp] = { :foo_tree => 'bar' }
      @el        = "test_element"
      @content   = "<div>Sample div element</div>"
    end

    context "#replace_partial" do
      it 'returns proper JS' do
        js_str = @presenter.replace_partial(@el, @content)
        js_str.should == "Element.replace('#{@el}','#{escape_javascript(@content)}');"
      end
    end

    context "#update_partial" do
      it 'returns proper JS' do
        js_str = @presenter.update_partial(@el, @content)
        js_str.should == "Element.update('#{@el}','#{escape_javascript(@content)}');"
      end
    end

    context "#replace_or_update_partial" do
      it 'replace returns proper JS' do
        js_str = @presenter.replace_or_update_partial('replace', @el, @content)
        js_str.should == "Element.replace('#{@el}','#{escape_javascript(@content)}');"
      end

      it 'update returns proper JS' do
        js_str = @presenter.replace_or_update_partial('update', @el, @content)
        js_str.should == "Element.update('#{@el}','#{escape_javascript(@content)}');"
      end
    end

    context "#set_or_undef" do
      it 'return proper JS for nil' do
        js_str = @presenter.set_or_undef(:var1)
        js_str.should == 'var1 = undefined;'
      end

      it 'return proper JS for a random value' do
        random_value = 'xxx' + rand(10).to_s
        @presenter['var2'] = random_value
        js_str = @presenter.set_or_undef(:var2)
        js_str.should == "var2 = '#{random_value}';"
      end
    end

    context "#ajax_action" do
      it 'returns JS to call miqAsyncAjax with proper url' do
        js_str = @presenter.ajax_action(
          :controller => 'foo',
          :action     => 'bar',
          :record_id  => 42,
        )
        js_str.should == "miqAsyncAjax('/foo/bar/42');"
      end
    end

    context "#replace_tree" do
      it 'returns JS to replace tree nodes' do
        js_str = @presenter.replace_tree(:foo, {})

        expected = <<EOD
var sel_node = foo_tree.getSelectedItemId();
var root_id = 'root';
foo_tree.deleteChildItems(0);
foo_tree.loadJSONObject(bar);
foo_tree.setItemCloseable(root_id,0);
foo_tree.showItemSign(root_id,false);
foo_tree.selectItem(sel_node);
foo_tree.openItem(sel_node);
EOD
        (js_str + "\n").should == expected
      end
    end

    context "#build_calendar" do
      it 'returns JS to build calendar with no options' do
        @presenter[:build_calendar] = true
        @presenter.build_calendar.should == 'miqBuildCalendar();'
      end

      it 'returns JS to build calendar with options' do
        @presenter[:build_calendar] = {
          :date_from => 'Fantomas',
          :date_to   => 'was',
          :skip_days => 'here!',
        }

        js_str = @presenter.build_calendar

        expected = <<EOD
miq_cal_dateFrom = new Date(Fantomas);
miq_cal_dateTo   = new Date(was);
miq_cal_skipDays = 'here!';
miqBuildCalendar();
EOD
        (js_str + "\n").should == expected
      end

      it 'returns JS to undefine a date' do
        @presenter[:build_calendar] = {
          :date_from => 'Fantomas is gone!',
          :date_to   => nil,
        }

        js_str = @presenter.build_calendar

        expected = <<EOD
miq_cal_dateFrom = new Date(Fantomas is gone!);
miq_cal_dateTo   = undefined;
miqBuildCalendar();
EOD
        (js_str + "\n").should == expected
      end
    end
  end
end

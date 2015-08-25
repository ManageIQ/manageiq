require "spec_helper"

describe ExplorerPresenter do
  context "partial methods" do
    before :each do
      @presenter = ExplorerPresenter.new
      @el        = "test_element"
      @content   = "<div>Sample div element</div>"
    end

    context "#replace_partial" do
      it 'returns proper JS' do
        js_str = @presenter.replace_partial(@el, @content)
        js_str.should == "$('##{@el}').replaceWith('#{escape_javascript(@content)}');"
      end
    end

    context "#update_partial" do
      it 'returns proper JS' do
        js_str = @presenter.update_partial(@el, @content)
        js_str.should == "$('##{@el}').html('#{escape_javascript(@content)}');"
      end
    end

    context "#set_or_undef" do
      it 'return proper JS for nil' do
        js_str = @presenter.set_or_undef("var1")
        js_str.should == 'ManageIQ.record.var1 = null;'
      end

      it 'return proper JS for a random value' do
        random_value = 'xxx' + rand(10).to_s
        @presenter['var2'] = random_value
        js_str = @presenter.set_or_undef("var2")
        js_str.should == "ManageIQ.record.var2 = '#{random_value}';"
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

    context "#build_calendar" do
      it 'calls js_build_calendar' do
        @presenter[:build_calendar] = true
        expect(@presenter).to receive(:js_build_calendar)
        @presenter.build_calendar
      end

      it 'calls js_build_calendar with params' do
        # with_indifferent_access because ExplorerPresenter#options is, and it's recursively infectious - ie. won't compare otherwise
        obj = {
          :date_from => Time.at(0).utc,
          :date_to   => Time.at(946684800).utc,
          :skip_days => [ 1, 2, 3 ],
        }.with_indifferent_access
        @presenter[:build_calendar] = obj
        expect(@presenter).to receive(:js_build_calendar).with(obj)
        @presenter.build_calendar
      end
    end
  end
end

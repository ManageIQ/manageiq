require "spec_helper"

describe JsHelper do
  context '#set_spinner_off' do
    it 'returns js to turn spinner off' do
      set_spinner_off.should eq('miqSparkleOff();')
    end
  end

  context '#set_element_visible' do
    it 'returns js to hide element' do
      set_element_visible('foo', false).should eq("if (miqDomElementExists('foo')) $('\#foo').hide();")
    end

    it 'returns js to show element' do
      set_element_visible('foo', true).should eq("if (miqDomElementExists('foo')) $('\#foo').show();")
    end
  end

  context '#tree_lock' do
    it 'returns js to lock tree' do
      tree_lock('bar', true).gsub(/^\s+/, '').should eq(<<-JS.strip_heredoc)
        $('#barbox').dynatree('disable');
        miqDimDiv('\#bar_div', true);
      JS
    end

    it 'returns js to unlock tree' do
      tree_lock('bar', false).gsub(/^\s+/, '').should eq(<<-JS.strip_heredoc)
        $('#barbox').dynatree('enable');
        miqDimDiv('\#bar_div', false);
      JS
    end
  end

  context '#javascript_focus' do
    it 'returns js to focus on an element' do
      javascript_focus('foo').should eq("$('#foo').focus();")
    end
  end

  context '#javascript_focus_if_exists' do
    it 'returns js to check for the existence of an element and focus on the element if it exists' do
      javascript_focus_if_exists('foo').should eq("if ($('#foo').length) $('#foo').focus();")
    end
  end

  context '#javascript_highlight' do
    it 'returns js to to add or remove the active class on the element' do
      javascript_highlight('foo', true).should eq("miqHighlight('\#foo', true);")
      javascript_highlight('foo', false).should eq("miqHighlight('\#foo', false);")
    end
  end

  context '#javascript_dim' do
    it 'returns js to to add or remove the dimmed class on the element' do
      javascript_dim('foo', true).should eq("miqDimDiv('\#foo', true);")
      javascript_dim('foo', false).should eq("miqDimDiv('\#foo', false);")
    end
  end

  context '#javascript_add_class' do
    it 'returns js to add a class on the element' do
      javascript_add_class('foo', 'bar').should eq("$('\#foo').addClass('bar');")
    end
  end

  context '#javascript_del_class' do
    it 'returns js to remove a class on the element' do
      javascript_del_class('foo', 'bar').should eq("$('\#foo').removeClass('bar');")
    end
  end

  context '#javascript_disable_field' do
    it 'returns js to disable the provided element' do
      javascript_disable_field('foo').should eq("$('#foo').prop('disabled', true);")
    end
  end

  context '#javascript_enable_field' do
    it 'returns js to enable the provided element' do
      javascript_enable_field('foo').should eq("$('#foo').prop('disabled', false);")
    end
  end

  context '#javascript_show' do
    it 'returns js to show an element' do
      javascript_show('foo').should eq("$('#foo').show();")
    end
  end

  context '#javascript_hide' do
    it 'returns js to hide an element' do
      javascript_hide('foo').should eq("$('#foo').hide();")
    end
  end

  context '#javascript_show_if_exists' do
    it 'returns js to check for the existence of an element and show the element if it exists' do
      javascript_show_if_exists('foo').should eq("if (miqDomElementExists('foo')) $('#foo').show();")
    end
  end

  context '#javascript_hide_if_exists' do
    it 'returns js to check for the existence of an element and hide the element if it exists' do
      javascript_hide_if_exists('foo').should eq("if (miqDomElementExists('foo')) $('#foo').hide();")
    end
  end

  context '#javascript_checked' do
    it 'returns js to check the provided input element of type checkbox' do
      javascript_checked(
        'foo'
      ).should eq("if ($('#foo').prop('type') == 'checkbox') {$('#foo').prop('checked', 'checked');}")
    end
  end

  context '#javascript_unchecked' do
    it 'returns js to uncheck the provided input element of type checkbox' do
      javascript_unchecked(
        'foo'
      ).should eq("if ($('#foo').prop('type') == 'checkbox') {$('#foo').prop('checked', false);}")
    end
  end

  context '#js_build_calendar' do
    it 'returns JS to build calendar with no options' do
      expected = <<EOD
ManageIQ.calendar.calDateFrom = undefined;
ManageIQ.calendar.calDateTo = undefined;
ManageIQ.calendar.calSkipDays = undefined;
miqBuildCalendar();
EOD

      js_build_calendar.should eq(expected)
    end

    it 'returns JS to build calendar with options' do
      opt = {:date_from => Time.at(0).utc,
             :date_to   => Time.at(946684800).utc,
             :skip_days => [ 1, 2, 3 ]}

      expected = <<EOD
ManageIQ.calendar.calDateFrom = new Date('1970-01-01T00:00:00Z');
ManageIQ.calendar.calDateTo = new Date('2000-01-01T00:00:00Z');
ManageIQ.calendar.calSkipDays = [1,2,3];
miqBuildCalendar();
EOD

      js_build_calendar(opt).should eq(expected)
    end
  end

  context '#js_format_date' do
    it 'returns undefined for nil' do
      js_format_date(nil).should eq('undefined')
    end

    it 'returns new Date with iso string as param' do
      js_format_date(Time.at(946684800).utc).should eq("new Date('2000-01-01T00:00:00Z')")
    end
  end
end

describe JsHelper do
  context '#set_spinner_off' do
    it 'returns js to turn spinner off' do
      expect(set_spinner_off).to eq('miqSparkleOff();')
    end
  end

  context '#set_element_visible' do
    it 'returns js to hide element' do
      expect(set_element_visible('foo', false)).to eq("if (miqDomElementExists('foo')) $('\#foo').hide();")
    end

    it 'returns js to show element' do
      expect(set_element_visible('foo', true)).to eq("if (miqDomElementExists('foo')) $('\#foo').show();")
    end
  end

  context '#tree_lock' do
    it 'returns js to lock tree' do
      expect(tree_lock('bar', true).gsub(/^\s+/, '')).to eq(<<-JS.strip_heredoc)
        miqTreeObject('bar').disableAll({silent: true, keepState: true});
        miqDimDiv('\#bar_div', true);
      JS
    end

    it 'returns js to unlock tree' do
      expect(tree_lock('bar', false).gsub(/^\s+/, '')).to eq(<<-JS.strip_heredoc)
        miqTreeObject('bar').enableAll({silent: true, keepState: true});
        miqDimDiv('\#bar_div', false);
      JS
    end
  end

  context '#javascript_focus' do
    it 'returns js to focus on an element' do
      expect(javascript_focus('foo')).to eq("$('#foo').focus();")
    end
  end

  context '#javascript_highlight' do
    it 'returns js to to add or remove the active class on the element' do
      expect(javascript_highlight('foo', true)).to eq("miqHighlight('\#foo', true);")
      expect(javascript_highlight('foo', false)).to eq("miqHighlight('\#foo', false);")
    end
  end

  context '#javascript_dim' do
    it 'returns js to to add or remove the dimmed class on the element' do
      expect(javascript_dim('foo', true)).to eq("miqDimDiv('\#foo', true);")
      expect(javascript_dim('foo', false)).to eq("miqDimDiv('\#foo', false);")
    end
  end

  context '#javascript_disable_field' do
    it 'returns js to disable the provided element' do
      expect(javascript_disable_field('foo')).to eq("$('#foo').prop('disabled', true);")
    end
  end

  context '#javascript_enable_field' do
    it 'returns js to enable the provided element' do
      expect(javascript_enable_field('foo')).to eq("$('#foo').prop('disabled', false);")
    end
  end

  context '#javascript_show' do
    it 'returns js to show an element' do
      expect(javascript_show('foo')).to eq("$('#foo').show();")
    end
  end

  context '#javascript_hide' do
    it 'returns js to hide an element' do
      expect(javascript_hide('foo')).to eq("$('#foo').hide();")
    end
  end

  context '#javascript_show_if_exists' do
    it 'returns js to check for the existence of an element and show the element if it exists' do
      expect(javascript_show_if_exists('foo')).to eq("if (miqDomElementExists('foo')) $('#foo').show();")
    end
  end

  context '#javascript_hide_if_exists' do
    it 'returns js to check for the existence of an element and hide the element if it exists' do
      expect(javascript_hide_if_exists('foo')).to eq("if (miqDomElementExists('foo')) $('#foo').hide();")
    end
  end

  context '#javascript_checked' do
    it 'returns js to check the provided input element of type checkbox' do
      expect(javascript_checked(
        'foo'
      )).to eq("if ($('#foo').prop('type') == 'checkbox') {$('#foo').prop('checked', true);}")
    end
  end

  context '#javascript_unchecked' do
    it 'returns js to uncheck the provided input element of type checkbox' do
      expect(javascript_unchecked(
        'foo'
      )).to eq("if ($('#foo').prop('type') == 'checkbox') {$('#foo').prop('checked', false);}")
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

      expect(js_build_calendar).to eq(expected)
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

      expect(js_build_calendar(opt)).to eq(expected)
    end
  end

  context '#js_format_date' do
    it 'returns undefined for nil' do
      expect(js_format_date(nil)).to eq('undefined')
    end

    it 'returns new Date with iso string as param' do
      expect(js_format_date(Time.at(946_684_800).utc)).to eq("new Date('2000-01-01T00:00:00Z')")
    end
  end
end

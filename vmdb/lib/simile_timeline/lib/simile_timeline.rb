# Copyright (c) 2006 Caesy Education Systems
#                    Duncan Beevers
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

class ActiveRecord::Base
  def self.acts_as_simile_timeline_event(attr)
    @@simile_timeline_fields = attr[:fields]

    define_method(:to_simile_timeline_JSON_event) do
      event = {}
      @@simile_timeline_fields.each_pair do |field, value|
        event[field] =
          case value
            when Symbol
              self.send(value)
            else
              value
          end
          case event[field]
            when Time
              event[field] = event[field].iso8601
          end
        end
      event.to_json
    end
  end
end

module Simile #:nodoc:
  module Timeline
    SPLIT_CHAR = "\n"

    class Timeline
      def initialize(attrs = {})
        # create bands
        add_themes(attrs[:themes])
        add_bands(attrs[:bands])
        create_band_index(attrs)
        @synchronizations   = attrs[:synchronize]
        @highlights         = attrs[:highlight]
        @event_source       = attrs[:event_source]
        @event_band         = attrs[:event_band]
      end

      attr_reader :event_source

      def add_themes(themes)
        @themes = {} if @themes.nil?
        themes = {} if themes.nil?
        raise "New Theme must be provided as a hash." unless themes.kind_of?(Hash)
        themes.each_pair do |name, attributes|
          @themes[name] = Theme.new(attributes)
        end
      end

      def add_bands(bands)
        @bands = {} if @bands.nil?
        bands = {} if bands.nil?
        raise "New Band must provided as a hash." unless bands.kind_of?(Hash)
        bands.each_pair do |name, attributes|
          @bands[name] = Band.new(attributes)
          @bands[name].timeline_js_id = js_id
        end
      end

      def create_band_index(attrs)
        # create the band_index for bands requested in a specific order
        @band_index = { }
        i = 0
        attrs[:bands_order].each do |band|
          @band_index[band] = i
          i += 1
        end if attrs[:bands_order]
        # append the remaining bands in whatever order
        last_index = @band_index.size
        @bands.each_key do |band|
          unless @band_index.has_key?(band) then
            @band_index[band] = last_index
            last_index += 1
          end
        end
        # create an array of the band names, in sorted order (according to the bands_order)
        @band_array = (@band_index.sort { |a,b| a[1]<=>b[1] }).flatten.delete_if { |a| a.class == Fixnum }
      end

      def js(event_source_url)
        [
          define_js,
          observers_js,
          onload_js(event_source_url),
          onresize_js,
          compute_url_js
        ].join(SPLIT_CHAR)
      end

      def js_id
        "timeline_#{__id__.abs}"
      end

      def compute_url_js
        [
          "function event_source_url(base_url,start,end){",
          "if (start==null){start = new Date();}",
          "if (end==null){end = new Date();}",
          "return base_url.replace('REPL_START', escape(start.toUTCString())).replace('REPL_END', escape(end.toUTCString()));",
          "}"
        ].join(SPLIT_CHAR)
      end

      def define_js
        [
          "var #{js_id};var #{js_id}_timer=null;",
          event_source_js
        ].join(SPLIT_CHAR)
      end

      def observers_js
        [
          "Event.observe(window,'load',function(){#{js_id}_onLoad()});",
          "Event.observe(window,'resize',function(){#{js_id}_onResize()});"
        ].join(SPLIT_CHAR)
      end

      def onload_js(event_source_url)
        [
          "function #{js_id}_onLoad(){",
          themes_js,
          bands_js,
          synchronization_js,
          highlight_js,
          "#{js_id}=Timeline.create($('#{js_id}'),#{js_id}_bands);",
          onscroll_js(event_source_url),
          event_load_js(event_source_url),
          "};"
        ].join(SPLIT_CHAR)
      end

      def onresize_js
        "function #{js_id}_onResize(){if (#{js_id}_timer==null){#{js_id}_timer=window.setTimeout(function(){#{js_id}_timer=null;#{js_id}.layout();#{js_id}.paint();},500);}};"
      end

      def themes_js
        out = []
        # define provided themes in JavaScript
        @themes.each_pair do |name, value|
          # out << "var #{name}_theme = $H(Timeline.ClassicTheme.create()).merge($H(#{value.to_json}));"
          out << "var #{name}_theme=Timeline.ClassicTheme.create();"
          out << descend_hash("#{name}_theme", YAML.load(value.to_json))
        end
        out.join(SPLIT_CHAR)
      end

      def descend_hash(prefix, hash)
        out = []
        hash.each_pair do |name, value|
          out << (value.kind_of?(Hash) ? descend_hash("#{prefix}.#{name}", value) : "#{prefix}.#{name}=#{value.to_json};")
        end
        out.join(SPLIT_CHAR)
      end

      def onscroll_js(event_source_url)
        [
          "#{js_id}.getBand(#{@band_index[@event_band]}).addOnScrollListener(function(timeline){",
          "if (#{js_id}_timer==null){",
          "#{js_id}_timer=window.setTimeout(function(){",
          "#{js_id}_timer=null;",
          "var start_date1=timeline.getMinDate();var start_date2=start_date1;",
          "var end_date1=timeline.getMaxDate();var end_date2=end_date1;",
          "var earliest_event=timeline.getEventSource().getEarliestDate();",
          "var latest_event=timeline.getEventSource().getLatestDate();",
          "if(start_date2<latest_event){start_date2=latest_event}",
          "if(end_date1>earliest_event){end_date1=earliest_event}",
          "if(end_date1>start_date1){",
          "Timeline.loadJSON(",
          "event_source_url(\"#{event_source_url}\",start_date1,end_date1),",
          "function(xml,url){#{js_id}_event_source.loadJSON(xml,url);})}",
          "if(end_date2>start_date2){",
          "Timeline.loadJSON(",
          "event_source_url(\"#{event_source_url}\",start_date2,end_date2),",
          "function(xml,url){#{js_id}_event_source.loadJSON(xml,url);})",
          "}}",
          ", 500)}});",
        ].join(SPLIT_CHAR)
      end

      def bands_js
        out = [ ]
        # create a unique variable for each band to be generated
        @bands.each_pair do |name, band| out << band.js end

        # create an array containing the bands
        band_ids = [ ]
        @band_array.each { |band| band_ids << @bands[band].js_id }
        out << "#{js_id}_bands=[" + band_ids.join(",") + "];"
        out.join(SPLIT_CHAR)
      end

      def event_source_js
        "var #{js_id}_event_source=new Timeline.DefaultEventSource();"
      end

      def event_load_js(event_source_url)
        "Timeline.loadJSON(event_source_url(\"#{event_source_url}\",#{js_id}.getBand(#{@band_index[@event_band]}).getMinDate(),#{js_id}.getBand(#{@band_index[@event_band]}).getMaxDate()),function(xml,url){#{js_id}_event_source.loadJSON(xml,url);});"
      end

      # Not sure why they decided to implement synchronization this way, but whatever
      def synchronization_js
        return "" if @synchronizations.nil?
        out = []
        @synchronizations.each_pair do |synch1, synch2|
          out << "#{js_id}_bands[#{@band_index[synch1]}].syncWith=#{@band_index[synch2]};"
        end
        out.join(SPLIT_CHAR)
      end

      def highlight_js
        return "" if @highlights.nil?
        out = []
        @highlights.each do |band|
          out << "#{js_id}_bands[#{@band_index[band]}].highlight=true;"
        end
        out.join(SPLIT_CHAR)
      end

      private :observers_js, :define_js, :onload_js, :onresize_js, :bands_js, :synchronization_js

    end # end class Timeline

    class TimelineChild
      def initialize(attrs)
        # @timeline_js_id = timeline_js_id
        raise "#{self.class} attributes must be provided as a hash." unless attrs.kind_of?(Hash)
        attrs.each_pair do |attribute_name, value|
          self.send(attribute_name.to_s + "=", value)
        end
        self_initialize if self.respond_to?(:self_initialize)
      end
      def self.attr_object(*objects)
        objects.each do |object|
          define_method((object.to_s + "=").to_sym) do |value|
            instance_variable_set("@#{object}".intern, ('::Simile::Timeline::' + object.to_s.capitalize).constantize.new(value))
          end
          define_method(object.to_sym) do
            instance_variable_get("@#{object}".intern)
          end
        end
      end
    end

    class Band < TimelineChild
      attr_accessor :timeline_js_id
      attr_accessor :width, :intervalPixels, :intervalUnit, :showEventText, :trackHeight, :trackGap, :date

      def timeline_js_id=(value)
        @eventSource = "#{value}_event_source"
      end

      def js_id
        "band_#{__id__.abs}"
      end

      # returns JavaScript defining this band
      def js
        attributes = []
        instance_values.each_pair do |attribute, value|
          attributes << attribute.to_s + ":" + value.to_s if value
        end

        [
          "var #{js_id}=Timeline.createBandInfo({",
          attributes.join(","),
          "});"
        ].join(SPLIT_CHAR)
      end

      def theme=(theme_name)
        @theme = "#{theme_name}_theme"
      end

    end # end class Band
    class Theme < TimelineChild
      attr_accessor :firstDayOfWeek
      attr_object :ether, :event
    end # end class Theme
    class Event < TimelineChild
      attr_object :track, :instant, :duration, :label, :bubble
      attr_accessor :highlightColors
    end # end class Event
    class Track < TimelineChild
      attr_accessor :offset, :height, :gap
    end
    class Instant < TimelineChild
      attr_accessor :icon, :lineColor, :impreciseColor, :impreciseOpacity, :showLineForNoText
    end
    class Duration < TimelineChild
      attr_accessor :color, :opacity, :impreciseColor, :impreciseOpacity
    end
    class Label < TimelineChild
      attr_accessor :insideColor, :outsideColor, :width
    end
    class Bubble < TimelineChild
      attr_accessor :width, :height, :titleStyler, :bodyStyler, :imageStyler, :timeStyler
    end # end class Bubble
    class Ether < TimelineChild
      attr_accessor :backgroundColors, :highlightColor, :highlightOpacity
      attr_object :interval
    end # end class Ether
    class Interval < TimelineChild
      attr_object :line, :weekend, :marker
    end # end class Interval
    class Line < TimelineChild
      attr_accessor :show, :color, :opacity
    end
    class Weekend < TimelineChild
      attr_accessor :color, :opacity
    end
    class Marker < TimelineChild
      attr_accessor :hAlign, :hBottomStyler, :hBottomEmphasizedStyler, :hTopStyler, :hTopEmphasizedStyler, :vAlign, :vRightStyler, :vRightEmphasizedStyler, :vLeftStyler, :vLeftEmphasizedStyler
    end

  end # end module Timeline
end # end module Simile


module SimileTimelineHelper #:nodoc:
  # declare the class level helper methods
  # which will load the relevant instance methods defined below when invoked
  def simile_timeline(timeline, options)
    options[:id] = "#{timeline.js_id}" unless options[:id]
    timeline_event_url = timeline.event_source.update( { :start => 'REPL_START', :end => 'REPL_END' } )
    content_tag('div', '', options) + javascript_tag(timeline.js(url_for(timeline_event_url)))
  end

  # called from the view to generate a Simile Timeline-consumable JSON event set
  # Example:
  # in recent.rhtml
  # <%= simile_timeline_JSON_events(@shipments) -%>
  def simile_timeline_JSON_events(events)
    events_JSON_array = []
    events.each do |event|
      events_JSON_array << event.to_simile_timeline_JSON_event
    end
    "{'dateTimeFormat':'iso8601','events':[" + events_JSON_array.join(",") + "]}"
  end
end # end module SimileTimelineHelper

# END simile_timeline.rb

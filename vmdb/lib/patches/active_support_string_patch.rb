require 'date'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # Converting strings to other objects
      module Conversions
#        def to_time(form = :utc)
#          d = ::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction).map { |arg| arg || 0 }
#          d[6] *= 1000000
#          ::Time.send("#{form}_time", *d)
#        end

        def to_datetime
          ::DateTime.civil(*::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec, :zone).map { |arg| arg || 0 })
#          d = ::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec, :zone, :sec_fraction).map { |arg| arg || 0 }
#          d[5] += d.pop
#          ::DateTime.civil(*d)
        end
      end
    end
  end
end

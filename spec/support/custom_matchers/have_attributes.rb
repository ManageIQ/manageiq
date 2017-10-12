RSpec::Matchers.define :have_attributes do |attrs|
  match do |obj|
    regexp = /(.*_spec\.rb:\d+)/
    called_from = caller.detect { |line| line =~ regexp }

    if obj.nil?
      @err_msg = "Unexpected call to have_attributes on NilClass"
    else
      @err_msg = nil
      attrs.each do |attr, expected|
        actual =
          if obj.respond_to?(attr)
            obj.send(attr)
          elsif obj.respond_to?(:[]) && !obj.kind_of?(ActiveRecord::Base)
            @array_access_used = true
            obj[attr]
          else
            RuntimeError.new("Unknown attribute '#{attr}'")
          end

        matcher = if actual.respond_to?(:acts_like_time?) && expected.respond_to?(:acts_like_time?)
                    be_same_time_as(expected)
                  elsif expected.kind_of?(RSpec::Matchers::BuiltIn::Match)
                    match(expected.expected)
                  else
                    eq(expected)
                  end

        unless matcher.matches?(actual)
          name_key = [:name, :id, :object_id].detect { |k| obj.respond_to?(k) }
          @err_msg ||= "with #{obj.class.name} #{name_key}:#{obj.send(name_key).inspect}\n\n"
          @err_msg << "testing attribute: \"#{attr}\"\n#{matcher.failure_message}\n\n"
        end
      end
    end


    if @array_access_used
      puts <<-MESSAGE
\nWARNING: Use of `have_attributes` with array access (:[]) is deprecated and will be removed shortly.
If you're matching attributes in hashes, use appropriate hash matchers instead (`include`, `eq`).
#{"Called from " + called_from if called_from}
      MESSAGE
    end
    @err_msg.nil?
  end

  failure_message do |_obj|
    @err_msg
  end

  failure_message_when_negated do |_obj|
    @err_msg
  end

  description do
    "have the same attributes as passed"
  end
end

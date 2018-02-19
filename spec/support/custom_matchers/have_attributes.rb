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
                    if expected == actual
                      eq(expected)
                    else
                      @depending_on_custom_approximation = true
                      be_within(0.1).of(expected)
                    end
                  elsif expected.kind_of?(RSpec::Matchers::BuiltIn::BaseMatcher)
                    expected
                  else
                    eq(expected)
                  end

        unless matcher.matches?(actual)
          name_key = [:name, :id, :object_id].detect { |k| obj.respond_to?(k) }
          @err_msg ||= "with #{obj.class.name} #{name_key}:#{obj.send(name_key).inspect}\n\n"
          @err_msg << "testing attribute: \"#{attr}\"\n#{matcher.failure_message}\n\n"

          if @depending_on_custom_approximation
            msg = <<~MESSAGE
              \nUse of approximate time matching in `have_attributes` is removed.
              If you expected the values to match here, this could actually be a bug in your code,
              though due to precision discrepancies you should be using approximate times or
              rounding your times with 'to_i' anyway.

              To match approximate times, use RSpec's composable matchers.
              e.g.: expect(thing).to have_attributes(:timestamp => a_value_within(0.1).of(expected))
              For more info, see https://github.com/ManageIQ/manageiq/pull/11474

              Spec failed with the following message:
              #{@err_msg}

              #{"Called from " + called_from if called_from}
            MESSAGE

            raise msg
          end
        end
      end
    end


    if @array_access_used
      msg = <<~MESSAGE
        \nUse of `have_attributes` with array access (:[]) is removed.
        If you're matching attributes in hashes, use appropriate hash matchers instead (`include`, `eq`).
        For more info, see https://github.com/ManageIQ/manageiq/pull/11474
        #{"Called from " + called_from if called_from}
      MESSAGE

      raise msg
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

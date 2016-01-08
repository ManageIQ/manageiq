RSpec::Matchers.define :have_attributes do |attrs|
  match do |obj|
    if obj.nil?
      @err_msg = "Unexpected call to have_attributes on NilClass"
    else
      @err_msg = nil
      attrs.each do |attr, expected|
        actual =
          if obj.respond_to?(attr)
            obj.send(attr)
          elsif obj.respond_to?(:[]) && !obj.kind_of?(ActiveRecord::Base)
            obj[attr]
          else
            RuntimeError.new("Unknown attribute '#{attr}'")
          end

        matcher = if actual.respond_to?(:acts_like_time?) && expected.respond_to?(:acts_like_time?)
                    be_same_time_as(expected)
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

module Quadicons
  module Quadrants
    class GuestCompliance < Quadrants::Base
      def path
        case compliance
        when true
          '100/check.png'
        when 'N/A'
          '100/na.png'
        else
          '100/x.png'
        end
      end

      def compliance
        record.passes_profiles?(context.policy_keys)
      end
    end
  end
end

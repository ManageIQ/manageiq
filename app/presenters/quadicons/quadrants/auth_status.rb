module Quadicons
  module Quadrants
    class AuthStatus < Quadrants::Base
      def path
        "100/#{h(img)}.png"
      end

      private

      def img
        case record.authentication_status
        when "Invalid" then "x"
        when "Valid"   then "checkmark"
        when "None"    then "unknown"
        else
          "exclamationpoint"
        end
      end
    end
  end
end

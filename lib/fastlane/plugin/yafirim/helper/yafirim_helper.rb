module Fastlane
  module Helper
    class YafirimHelper
      # class methods that you define here become available in your action
      # as `Helper::YafirimHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the yafirim plugin helper!")
      end
    end
  end
end

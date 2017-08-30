require 'faraday' # HTTP Client
require 'faraday_middleware'

module Fastlane
  module Actions
    class YafirimAction < Action
      @token_url = 'http://api.fir.im/apps'
      @app_info = {}
      @options = {}

      def self.run(params)
        UI.message("Yafirim Begin process")
        @options = params
        @platform = @options[:file].end_with?(".ipa") ? 'ios' : 'android'

        UI.message(params)
        # app_info.merge!( get_upload_token )
        
        # begin
        #   upload_binary
        # rescue Exception => e
        #   raise e
        # end
      end

      def validation_response response_data
        error_code = response_data['code'].to_i rescue 0
        if error_code == 100020
          UI.user_error!("Firim API Token(#{options[:firim_api_token]}) not correct")
        end
      end

      def get_upload_token
        firim_client = Faraday.new(@token_url,
                                   {
                                     request: {
                                       timeout:       300,
                                       open_timeout:  300
                                     }
                                   }
                                  ) do |c|
          c.request  :url_encoded             # form-encode POST params
          c.adapter  :net_http
          c.response :json, :content_type => /\bjson$/
        end
        
        response = firim_client.post do |req|
          req.url @token_url
          req.body = { :type => @platform, :bundle_id => @options[:bundle_id], :api_token => @options[:api_token] }
        end

        info = response.body
        validation_response info
      end

      def upload_binary
        
      end

      def self.description
        "Yet another fastlane fir.im plugin"
      end

      def self.authors
        ["wd"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "A fastlane plugin to help you upload your ipa/apk to fir.im"
      end

      def self.available_options
        [
          # FastlaneCore::ConfigItem.new(key: :file,
          #                         env_name: "FILE",
          #                      description: "ipa/apk file path",
          #                         optional: false,
          #                             type: String)

          FastlaneCore::ConfigItem.new(key: :api_token,
                                       short_option: "-a",
                                       optional: true,
                                       description: "fir.im user api token"),

          # Content path
          FastlaneCore::ConfigItem.new(key: :file,
                                       short_option: "-f",
                                       env_name: "DELIVER_FILE_PATH",
                                       description: "Path to your ipa/akp file",
                                       default_value: Dir["*.ipa"].first || Dir["*.apk"].first,
                                       verify_block: proc do |value|
                                         UI.user_error!("Could not find ipa/apk file at path '#{value}'") unless File.exist?(value)
                                         UI.user_error!("'#{value}' doesn't seem to be an ipa/apk file") unless value.end_with?(".ipa") || value.end_with?(".apk")
                                       end,
                                       conflicting_options: [:pkg],
                                       conflict_block: proc do |value|
                                         UI.user_error!("You can't use 'file' and '#{value.key}' options in one run.")
                                       end),


          FastlaneCore::ConfigItem.new(key: :bundle_id,
                                       description: "bundle id",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :name,
                                       description: "app name",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "app version",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :build,
                                       description: "app build number",
                                       optional: true),

        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Platforms.md
        #
        [:ios, :android].include?(platform)
      end
    end
  end
end

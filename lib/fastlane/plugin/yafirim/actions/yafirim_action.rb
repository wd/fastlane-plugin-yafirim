require 'faraday' # HTTP Client

module Fastlane  
  module Actions
    class YafirimAction < Action
      @token_url = 'http://api.fir.im/apps'
      @app_info = {}

      def self.run(params)
        UI.message("Yafirim Begin process")
        @options = params
        if @options[:ipa]
          @platform = 'ios'
          Yafirim::DetectIosValues.new.run!(@options)
          @options[:file] = @options[:ipa]
        else
          @platform = 'android'
          Yafirim::DetectAndroidValues.new.run!(@options)
          @options[:file] = @options[:apk_path] + @options[:name] + "_" + @options[:version] + "_" + @options[:build_version] + "_" + @options[:build_type] + ".apk"
        end

        UI.user_error!("Error, file #{@options[:file]} not exists.") unless File.exist?(@options[:file])
        FastlaneCore::PrintTable.print_values(config: @options)

        binary_info = self.get_upload_token

        begin
          self.upload_binary binary_info
        rescue Exception => e
          raise e
        end
      end

      def self.validation_response response_data
        error_code = response_data['code'].to_i rescue 0
        if error_code == 100020
          UI.user_error!("Firim API Token(#{@options[:api_token]}) not correct")
        end
      end

      def self.get_upload_token
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
        self.validation_response info

        UI.message(info)
        UI.message(info['cert']['binary'])
        return info['cert']['binary']
      end

      def self.upload_binary binary_info
        params = {
          'key' => binary_info['key'],
          'token' => binary_info['token'],
          'file' => Faraday::UploadIO.new(@options[:file], 'application/octet-stream'),
          'x:name' => @options[:name],
          'x:version' => @options[:version],
          'x:build' => @options[:build_version]
        }

        UI.message "Start upload #{@options[:name]} binary..."

        firim_client = Faraday.new(nil,
                                   {
                                     request: {
                                       timeout:       1000,
                                       open_timeout:  300
                                     }
                                   }
                                  ) do |c|
          c.request :multipart
          c.request :url_encoded
          c.response :json, content_type: /\bjson$/
          c.adapter :net_http
        end

        response = firim_client.post binary_info['upload_url'], params
        unless response.body['is_completed']
          raise UI.user_error!("Upload binary to Qiniu error #{response.body}")
        end
        UI.success 'Upload binary successed!'
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
          FastlaneCore::ConfigItem.new(key: :api_token,
                                       short_option: "-a",
                                       optional: true,
                                       description: "fir.im user api token"),

          # Content path
          FastlaneCore::ConfigItem.new(key: :ipa,
                                       short_option: "-i",
                                       optional: true,
                                       description: "Path to your ipa file",
                                       default_value: Dir["*.ipa"].first,
                                       verify_block: proc do |value|
                                         UI.user_error!("Could not find ipa file at path '#{value}'") unless File.exist?(value)
                                         UI.user_error!("'#{value}' doesn't seem to be an ipa file") unless value.end_with?(".ipa")
                                       end,
                                       conflicting_options: [:apk_path],
                                       conflict_block: proc do |value|
                                         UI.user_error!("You can't use 'ipa' and '#{value.key}' options in one run.")
                                       end),

          FastlaneCore::ConfigItem.new(key: :apk_path,
                                       short_option: "-p",
                                       optional: true,
                                       description: "Path to your apk file",
                                       default_value: "./app/build/outputs/apk/",
                                       verify_block: proc do |value|
                                         UI.user_error!("Directory '#{value}' not exists.") unless Dir.exist?(value)
                                       end,
                                       conflicting_options: [:ipa],
                                       conflict_block: proc do |value|
                                         UI.user_error!("You can't use 'apk_path' and '#{value.key}' options in one run.")
                                       end),

          FastlaneCore::ConfigItem.new(key: :file,
                                       description: "file",
                                       optional: true),

          FastlaneCore::ConfigItem.new(key: :bundle_id,
                                       description: "bundle id",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :name,
                                       description: "app name",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "app version",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :build_version,
                                       description: "app build version number",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :build_type,
                                       description: "app build type",
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

  
  module Yafirim
    class DetectIosValues
      def run!(options)
        find_app_identifier(options)
        find_app_name(options)
        find_version(options)
        find_build_version(options)
      end

      def find_app_identifier(options)
        identifier = FastlaneCore::IpaFileAnalyser.fetch_app_identifier(options[:ipa])
        if identifier.to_s.length != 0
          options[:bundle_id] = identifier
        else
          UI.user_error!("Could not find ipa with app identifier '#{options[:app_identifier]}' in your iTunes Connect account (#{options[:username]} - Team: #{Spaceship::Tunes.client.team_id})")
        end
      end

      def find_app_name(options)
        return if options[:name]
        plist = FastlaneCore::IpaFileAnalyser.fetch_info_plist_file(options[:ipa])
        options[:name] ||= plist['CFBundleDisplayName']
        options[:name] ||= plist['CFBundleName']
      end

      def find_version(options)
        options[:version] ||= FastlaneCore::IpaFileAnalyser.fetch_app_version(options[:ipa])
      end

      def find_build_version(options)
        plist = FastlaneCore::IpaFileAnalyser.fetch_info_plist_file(options[:ipa])
        options[:build_version] = plist['CFBundleVersion']
      end
    end

    class DetectAndroidValues
      def run!(options)
        find_app_identifier(options)
        find_app_name(options)
        find_version(options)
        find_build_version(options)
      end

      def find_app_identifier(options)
        return if options[:bundle_id]
        out = `grep 'applicationId' app/build.gradle | awk -F '"' '{print $2}'`
        options[:bundle_id] = out.chomp
      end

      def find_app_name(options)
        return if options[:name]
        out = `grep 'def appName' app/build.gradle | awk -F '"' '{print $2}'`
        options[:name] = out.chomp
      end

      def find_version(options)
        return if options[:version]
        out = `grep ' versionName "' app/build.gradle | awk -F '"' '{print $2}'`
        options[:version] = out.chomp
      end

      def find_build_version(options)
        return if options[:build_version]
        out = `grep '   versionCode ' app/build.gradle | awk -F ' *' '{print $3}'`
        options[:build_version] = out.chomp
      end
    end

  end
end

module Fastlane
  module Actions
    class OneskyDownloadAppDescriptionParallelAction < Action
      def self.run(params)
        Actions.verify_gem!('onesky-ruby')
        require 'onesky'

        client = ::Onesky::Client.new(params[:public_key], params[:secret_key])
        project = client.project(params[:project_id])

        threads = []
        params[:locales].each do |locale|
          destination = "#{params[:destination_dir]}/#{locale}"
          UI.success "Downloading translation '#{locale}' of app description from OneSky to: '#{destination}'"

          threads << Thread.new do
            # see https://github.com/onesky/api-documentation-platform/blob/f4621ed1fa2fd6372d0abba4fef3dbf83ec43587/resources/translation.md#app-description---export-translations-of-app-store-description-in-json
            json = project.export_app_description(locale: locale)
            if json.nil? || json.empty?
              return UI.warn "Couldn't download app description for '#{locale}'"
            end

            resp = JSON.parse(json)
            resp['data'].each do |key, value|
              if mapped_filename = self.class.map_filename(key)
                path = File.join(destination, mapped_filename)
                File.open(path, 'w') { |file| file.write(value) }
              else
                next
              end
            end
          end
        end

        threads.each { |t| t.join }
      end

      def self.map_filename(key)
        {
          'APP_NAME' => 'name.txt',
          'APP_SUBTITLE' => 'subtitle.txt',
          'APP_PROMOTIONAL_TEXT' => 'promotional_text.txt',
          'APP_DESCRIPTION' => 'description.txt',
          'APP_KEYWORD' => 'keywords.txt',
          'APP_VERSION_DESCRIPTION' => 'release_notes.txt',
        }[key]
      end

      def self.description
        <<~EOS
        Download translation files for app description from OneSky in parallel.
        By default, this outputs files in names used in `fastlane/deliver` to manage metadata to under the directory specified by "destination_dir".'
        EOS
      end

      def self.authors
        ['ainame']
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :public_key,
                                       env_name: 'ONESKY_PUBLIC_KEY',
                                       description: 'Public key for OneSky',
                                       is_string: true,
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise "No Public Key for OneSky given, pass using `public_key: 'token'`".red unless value and !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :secret_key,
                                       env_name: 'ONESKY_SECRET_KEY',
                                       description: 'Secret Key for OneSky',
                                       is_string: true,
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise "No Secret Key for OneSky given, pass using `secret_key: 'token'`".red unless value and !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :project_id,
                                       env_name: 'ONESKY_PROJECT_ID',
                                       description: 'Project Id to upload file to',
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise "No project id given, pass using `project_id: 'id'`".red unless value and !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :locales,
                                       env_name: 'ONESKY_DOWNLOAD_LOCALE',
                                       description: 'Locale to download the translation for',
                                       is_string: false,
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise 'No locale for translation given'.red unless value and !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :destination_dir,
                                       env_name: 'ONESKY_DOWNLOAD_DESTINATION_DIR',
                                       description: 'Destination directory to put the downloaded files to',
                                       is_string: true,
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise "Please specify the filename of the desrtination file you want to download the translations to using `destination: 'filename'`".red unless value and !value.empty?
                                       end)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end

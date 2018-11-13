module Fastlane
  module Actions
    class RunRoboTestsFirebaseTestlabAction < Action
      @client_secret_file = "client-secret.json"
      @test_console_output_file = "robo_output1.txt"

      class << self
        attr_reader :client_secret_file, :test_console_output_file
      end

      def self.run(params)
        UI.message("Starting run_tests_firebase_testlab plugin...")
        if params[:gcloud_service_key_file].nil?
          UI.message("Save Google Cloud credentials.")
          File.open(@client_secret_file, 'w') do |file|
            file.write(ENV["GCLOUD_SERVICE_KEY"])
          end
        else
          @client_secret_file = params[:gcloud_service_key_file]
        end

        UI.message("Set Google Cloud target project.")
        Action.sh("#{Commands.config} #{params[:project_id]}")

        UI.message("Authenticate with Google Cloud.")
        Action.sh("#{Commands.auth} --key-file #{@client_secret_file}")

        UI.message("Running instrumentation tests in Firebase Test Lab...")

        device_configuration = ""
        params[:model].split(",").each_with_index do |model1, index|
          print(model1)
          print(index)
          print(params[:version].split(",")[index])
          device_configuration += "--device model=#{model1},version=#{params[:version].split(",")[index]},locale=#{params[:locale].split(",")[index]},orientation=#{params[:orientation].split(",")[index]} "\

        end

        # remove_pipe_if_exists
        # Action.sh("mkfifo #{PIPE}")
        # Action.sh("tee #{@test_console_output_file} < #{PIPE} & "\
                  # "#{Commands.run_tests} "\
        Action.sh("#{Commands.run_beta_tests} "\
                  "--type robo "\
                  "--app #{params[:app_apk]} "\
                  "--timeout #{params[:timeout]} "\
                  "--robo-directives #{params[:robo_directives]} "\
                  "#{device_configuration}"\
                  "--robo-script #{params[:robo_script]} "\
                  "#{params[:extra_options]} "\
                  "2>&1 | tee #{@test_console_output_file}")
        # remove_pipe_if_exists

        UI.message("Create firebase directory (if not exists) to store test results.")
        FileUtils.mkdir_p(params[:output_dir])

        if params[:bucket_url].nil?
          UI.message("Parse firebase bucket url.")
          params[:bucket_url] = Helper.scrape_bucket_url(@test_console_output_file)
          UI.message("bucket: #{params[:bucket_url]}")
        end

        UI.message("Downloading instrumentation test results from Firebase Test Lab...")
        Action.sh("#{Commands.download_results} #{params[:bucket_url]} #{params[:output_dir]}/")

        if params[:delete_firebase_files]
          UI.message("Deleting files from firebase storage...")
          Action.sh("#{Commands.delete_resuls} #{params[:bucket_url]}")
        end

        return {"result_bucket_url" => Helper.real_bucket_url(@test_console_output_file), "test_lab_console_url" => Helper.test_lab_console_url(@test_console_output_file), "test_failed" => Helper.has_failed_tests(@test_console_output_file)}

      end

      def self.description
        "Runs Android tests in Firebase Test Lab."
      end

      def self.authors
        ["bffcorreia"]
      end

      def self.details
        [
            "Authenticates with Google Cloud.",
            "Runs tests in Firebase Test Lab.",
            "Fetches the results to a local directory.",
            "Deletes the results from firebase bucket if wanted."
        ].join("\n")
      end

      def self.output
        [
            ['bugreport.txt', 'A bugreport of the app.'],
            ['instrumentation.results', 'The results of the instrumentation tests.'],
            ['logcat', 'Logs from logcat.'],
            ['test_result_0.xml', 'A xml file that contains all the tests.'],
            ['video.mp4', 'A video of the tests.']
        ]
      end

      def self.available_options
        [
            FastlaneCore::ConfigItem.new(key: :project_id,
                                         env_name: "PROJECT_ID",
                                         description: "Your Firebase project id",
                                         is_string: true,
                                         optional: false),
            FastlaneCore::ConfigItem.new(key: :model,
                                         env_name: "MODEL",
                                         description: "The device's model on which the tests will be run",
                                         is_string: true,
                                         optional: false),
            FastlaneCore::ConfigItem.new(key: :version,
                                         env_name: "VERSION",
                                         description: "The Android api version of the device",
                                         is_string: true,
                                         optional: false),
            FastlaneCore::ConfigItem.new(key: :app_apk,
                                         env_name: "APP_APK",
                                         description: "The path for your app apk. Default: app/build/outputs/apk/debug/app-debug.apk",
                                         is_string: true,
                                         optional: true,
                                         default_value: "app/build/outputs/apk/debug/app-debug.apk"),
            FastlaneCore::ConfigItem.new(key: :locale,
                                         env_name: "LOCALE",
                                         description: "The locale to test against. Default: en_US",
                                         is_string: true,
                                         optional: true,
                                         default_value: "en_US"),
            FastlaneCore::ConfigItem.new(key: :orientation,
                                         env_name: "ORIENTATION",
                                         description: "The orientation of the device. Default: portrait",
                                         is_string: true,
                                         optional: true,
                                         default_value: "portrait"),
            FastlaneCore::ConfigItem.new(key: :timeout,
                                         env_name: "TIMEOUT",
                                         description: "The max time this test execution can run before it is cancelled. Default: 30m",
                                         is_string: true,
                                         optional: true,
                                         default_value: "30m"),
            FastlaneCore::ConfigItem.new(key: :output_dir,
                                         env_name: "OUTPUT_DIR",
                                         description: "The directory to save the output results. Default: firebase",
                                         is_string: true,
                                         optional: true,
                                         default_value: "firebase"),
            FastlaneCore::ConfigItem.new(key: :bucket_url,
                                         env_name: "BUCKET_URL",
                                         description: "The bucket url where the test results were stored. Default: Parsed automatically from tests output",
                                         is_string: true,
                                         optional: true,
                                         default_value: nil),
            FastlaneCore::ConfigItem.new(key: :delete_firebase_files,
                                         env_name: "DELETE_FIREBASE_FILES",
                                         description: "A flag to controll if the firebase files should be deleted from the bucket or not. Default: false",
                                         is_string: false,
                                         optional: true,
                                         default_value: false),

            FastlaneCore::ConfigItem.new(key: :robo_directives,
                                         env_name: "ROBO_DIRECTIVES",
                                         description: "A comma-separated (<type>:<key>=<value>) map of robo_directives that you can use to customize the behavior of Robo test. The type specifies the action type of the directive, which may take on values click or text. If no type is provided, text will be used by default. Each key should be the Android resource name of a target UI element and each value should be the text input for that element. Values are only permitted for text type elements, so no value should be specified for click type elements. For example, use",
                                         is_string: true,
                                         optional: true,
                                         default_value: ""),
            FastlaneCore::ConfigItem.new(key: :robo_script,
                                         env_name: "ROBO_SCRIPT",
                                         description: "The path to a Robo Script JSON file. The path may be in the local filesystem or in Google Cloud Storage using gs:// notation. You can guide the Robo test to perform specific actions by recording a Robo Script in Android Studio and then specifying this argument",
                                         is_string: true,
                                         optional: true,
                                         default_value: ""),

            FastlaneCore::ConfigItem.new(key: :extra_options,
                                         env_name: "EXTRA_OPTIONS",
                                         description: "Extra options that you need to pass to the gcloud command. Default: empty string",
                                         is_string: true,
                                         optional: true,
                                         default_value: ""),
            FastlaneCore::ConfigItem.new(key: :gcloud_service_key_file,
                                         env_name: "GCLOUD_SERVICE_KEY_FILE",
                                         description: "File path containing the gcloud auth key. Default: Created from GCLOUD_SERVICE_KEY environment variable",
                                         is_string: true,
                                         optional: true,
                                         default_value: nil)
        ]
      end

      def self.is_supported?(platform)
        platform == :android
      end

      def self.example_code
        [
            `run_tests_firebase_testlab(
              project_id: "your-firebase-project-id",
              model: "Nexus6P",
              version: "27",
              delete_firebase_files: true
          )`
        ]
      end

      def self.category
        :testing
      end

    end
  end
end

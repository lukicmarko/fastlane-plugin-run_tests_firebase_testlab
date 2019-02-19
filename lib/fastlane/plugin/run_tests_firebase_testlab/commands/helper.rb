module Fastlane
  module Helper
    @client_secret_file = "client-secret.json"

    class << self
        attr_reader :client_secret_file
    end

    def self.scrape_bucket_url(test_console_output_file)
      File.open(test_console_output_file).each do |line|
        url_array = line.scan(/\[(.*)\]/).last
        url = nil
        unless url_array.nil?
          url = url_array.first
        end
        next unless !url.nil? and (!url.empty? and url.include?("test-lab-"))
        splitted_url = url.split('/')
        length = splitted_url.length
        return "gs://#{splitted_url[length - 2]}/#{splitted_url[length - 1]}"
      end
    end

    def self.has_failed_tests(test_console_output_file)
      File.open(test_console_output_file).each do |line|
        line_failed = line.scan(/\| Failed  \|/)

        next if line_failed.nil?
        next if line_failed.first.nil?
        print(line)
        return true
      end

      File.open(test_console_output_file).each do |line|
        line_failed = line.scan(/failed/)

        next if line_failed.nil?
        next if line_failed.first.nil?
        print(line)
        return true
      end

      return false
    end

    def self.real_bucket_url(test_console_output_file)
      File.open(test_console_output_file).each do |line|
        url_array = line.scan(/\[(.*)\]/).last
        url = ""
        unless url_array.nil?
          url = url_array.first
        end
        unless !url.nil? and (!url.empty? and url.include?("test-lab-"))
          next
        end
        return url
      end
    end

    def self.test_lab_console_url(test_console_output_file)
      File.open(test_console_output_file).each do |line|
        url_array = line.scan(/\[(.*)\]/).last
        url = ""
        unless url_array.nil?
          url = url_array.first
        end
        unless !url.nil? and (!url.empty? and url.include?("\/testlab\/histories\/"))
          next
        end
        return url
      end
    end

    def self.run_test(params, test_type, test_console_output_file)
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
        remove_pipe_if_exists
        Action.sh("mkfifo #{PIPE}")
        Action.sh("tee #{@test_console_output_file} < #{PIPE} & "\
                  "#{Commands.run_tests} "\
                  "--type instrumentation "\
                  "--app #{params[:app_apk]} "\
                  "--test #{params[:android_test_apk]} "\
                  "--device model=#{params[:model]},version=#{params[:version]},locale=#{params[:locale]},orientation=#{params[:orientation]} "\
                  "--timeout #{params[:timeout]} "\
                  "#{params[:extra_options]} > #{PIPE} 2>&1")
        remove_pipe_if_exists

        UI.message("Create firebase directory (if not exists) to store test results.")
        FileUtils.mkdir_p(params[:output_dir])

        if params[:bucket_url].nil?
          UI.message("Parse firebase bucket url.")
          params[:bucket_url] = scrape_bucket_url
          UI.message("bucket: #{params[:bucket_url]}")
        end

        UI.message("Downloading instrumentation test results from Firebase Test Lab...")
        Action.sh("#{Commands.download_results} #{params[:bucket_url]} #{params[:output_dir]}")

        if params[:delete_firebase_files]
          UI.message("Deleting files from firebase storage...")
          Action.sh("#{Commands.delete_resuls} #{params[:bucket_url]}")
        end
  end
end

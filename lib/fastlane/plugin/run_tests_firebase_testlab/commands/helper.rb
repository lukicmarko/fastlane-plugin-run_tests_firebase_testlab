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

      UI.message("Running" + test_type + "tests in Firebase Test Lab...")

      device_configuration = ""
      params[:model].split(',').each_with_index do |model1, index|
        print(model1)
        print(index)
        print(params[:version].split(',')[index])
        device_configuration += "--device model=#{model1},version=#{params[:version].split(',')[index]},locale=#{params[:locale].split(',')[index]},orientation=#{params[:orientation].split(',')[index]} "\
      end

      
      if test_type == "instrumentation"
        command = "sudo #{Commands.run_tests} "\
                   "--test #{params[:android_test_apk]} "
      end
      if test_type == "robo"
        command = "sudo #{Commands.run_beta_tests} "\
                   "--robo-script #{params[:robo_script]} "\
                   "#{params[:extra_options]} "
      end
      command += "--app #{params[:app_apk]} "\
                "--timeout #{params[:timeout]} "\
                "#{device_configuration}"\
                "--type #{test_type} "\
                " 2>&1 | tee " + test_console_output_file
      Action.sh(command)

      UI.message("Create firebase directory (if not exists) to store test results.")
      FileUtils.mkdir_p(params[:output_dir])

      if params[:bucket_url].nil?
        UI.message("Parse firebase bucket url.")
        params[:bucket_url] = scrape_bucket_url(test_console_output_file)
        UI.message("bucket: #{params[:bucket_url]}")
      end

      UI.message("Downloading instrumentation test results from Firebase Test Lab...")
      Action.sh("#{Commands.download_results} #{params[:bucket_url]} #{params[:output_dir]}")

      if params[:delete_firebase_files]
        UI.message("Deleting files from firebase storage...")
        Action.sh("#{Commands.delete_resuls} #{params[:bucket_url]}")
      end

      UI.message("Helper test END")
      return { "result_bucket_url" => real_bucket_url(test_console_output_file), "test_lab_console_url" => test_lab_console_url(test_console_output_file), "test_failed" => has_failed_tests(test_console_output_file) }
    end
  end
end

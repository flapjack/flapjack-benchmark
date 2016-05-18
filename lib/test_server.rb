require 'config'
require 'server_config'

module Flapjack
  module Benchmark
    # Slightly dodgey way of starting a local Flapjack server, taking
    # advantage of Appraisals rebundling of the correct Flapjack gem.
    #
    # A better way would be to recreate the GLI code that Flapjack uses to run
    # itself from the command line. This will do for now.
    class TestServer
      class << self
        def start
          kill_old_server
          start_new_server
        end

        def stop
          kill_old_server
        end

        private

        def kill_old_server
          current_pid = fetch_pid
          begin
            if current_pid
              Process.kill('SIGINT', current_pid)
              store_pid(nil)
            end
          rescue
            puts "Could not kill server with pid #{current_pid}"
          end
        end

        def start_new_server
          tmp_dir = Flapjack::Benchmark::Config.log_dir
          appraisal_env = Flapjack::Benchmark::Config.appraisal_environment

          server_std_out = File.join(tmp_dir, "std_out_#{appraisal_env}")
          server_std_err = File.join(tmp_dir, "std_err_#{appraisal_env}")

          new_pid = Process.spawn(
            server_env_vars,
            server_command,
            out: server_std_out,
            err: server_std_err
          )

          Process.detach(new_pid)
          store_pid(new_pid)
        end

        def pid_filename
          pid_dir = Flapjack::Benchmark::Config.pid_dir
          File.join(pid_dir, 'flapjack_server.pid')
        end

        def fetch_pid
          return nil unless File.exist?(pid_filename)

          pid_str = File.read(pid_filename)
          return nil if pid_str.empty?

          pid_str.to_i
        end

        def server_env_vars
          return {} unless ENV['PROFILE']

          profile_path = File.join(
            Flapjack::Benchmark::Config.tmp_dir,
            ENV['PROFILE']
          )

          perftools_bundle = `gem which perftools | tail -1`

          {
            'CPUPROFILE' => profile_path,
            'RUBYOPT' => "-r #{perftools_bundle}"
          }
        end

        def server_command
          #    appraisal_env = Flapjack::Benchmark::Config.appraisal_environment
          config_path = Flapjack::Benchmark::ServerConfig.create_config_file!
          server_config = "--config=#{config_path} server start --no-daemonize"

          "bundle exec flapjack #{server_config}"
        end

        def store_pid(pid)
          FileUtils.mkdir_p(Flapjack::Benchmark::Config.pid_dir)
          File.write(pid_filename, pid.to_s)
        end
      end
    end
  end
end

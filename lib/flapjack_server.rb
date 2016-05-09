# Slightly dodgey way of starting a local Flapjack server, taking advantage of Appraisals rebundling of the correct Flapjack gem.
#
# A better way would be to recreate the GLI code that Flapjack uses to run itself from the command line. This will do for now.

require 'config'
require 'flapjack_config_builder'

module Flapjack
  class LocalServer
    def self.start
      current_pid = get_pid

      kill_server(current_pid) if current_pid
      
      server_command = "bundle exec flapjack --config=#{config_path} server start --no-daemonize"
      
      server_std_out = File.join(APPLICATION_ROOT, 'tmp', 'std_out')
      server_std_err = File.join(APPLICATION_ROOT, 'tmp', 'std_err')
      
      new_pid = Process.spawn(server_command, out: server_std_out, err: server_std_err)
      Process.detach(new_pid)
      set_pid(new_pid)
      # SMELL This is a lame way to wait for server to start, but unfortunately there's no simple way to
      # determine if the server is running and ready. Calls to `server status` routinely returns "Starting",
      # even when the system is ready to accept incoming requests.
      # One way would be to follow the log until "flapjack-processor :: Booting main loop." appears.
      sleep(10)
    end

    def self.stop
      current_pid = get_pid
      kill_server(current_pid) if current_pid
    end

    def self.kill_server(pid)
      Process.kill('SIGINT', pid)
      set_pid(nil)
    rescue
      puts "Could not kill server with pid #{pid}"
    end

    private

    def self.config_path
      Flapjack::ConfigBuilder.config_path
    end

    def self.pids_path
      File.join(APPLICATION_ROOT, 'tmp', 'pids')
    end

    def self.pid_filename
      File.join(pids_path, 'flapjack_server.pid')
    end

    def self.get_pid
      return nil unless File.exist?(pid_filename)

      pid_str = File.read(pid_filename)
      return nil if pid_str.empty?

      pid_str.to_i
    end

    def self.set_pid(pid)
      FileUtils.mkdir_p(pids_path)
      File.write(pid_filename, pid.to_s)
    end
  end
end

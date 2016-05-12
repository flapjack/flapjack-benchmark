require 'yaml'
require 'flapjack/version'

module Flapjack
  module Benchmark
    class Config
      APPLICATION_ROOT = File.expand_path(File.join(File.dirname(File.expand_path(__FILE__)), '../')) unless defined? APPLICATION_ROOT

      FLAPJACK_VERSION = 'flapjack_' + Flapjack::VERSION.tr('.', '_') unless defined? FLAPJACK_VERSION
      CONFIG = YAML.load_file(File.join(APPLICATION_ROOT, 'flapjack-benchmark.yml'))[FLAPJACK_VERSION] unless defined? CONFIG

      class << self
        def tmp_dir
          File.join(APPLICATION_ROOT, 'tmp')
        end

        def log_dir
          File.join(APPLICATION_ROOT, 'log')
        end

        def pid_dir
          File.join(tmp_dir, 'pids')
        end

        def redis_config
          CONFIG['redis']
        end

        def jsonapi_config
          CONFIG['jsonapi']
        end
      end
    end
  end
end

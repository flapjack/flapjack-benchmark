require 'yaml'
require 'flapjack/version'

module Flapjack
  module Benchmark
    
    class SettingsDataMissing < Exception
      def message
        "Cannot find settings data. Check appraisal version is used as key." 
      end
    end
      
    class SettingsFileMissing < Exception
      def message
        "Cannot find settings file. Check 'flapjack-benchmark.yml' exists." 
      end
    end
    
    class Config

      FLAPJACK_VERSION = 'flapjack_' + Flapjack::VERSION.tr('.', '_') unless defined? FLAPJACK_VERSION

      class << self
      
        def settings
          @settings ||= load_settings
        end
        
        def application_root
          @application_root ||= File.expand_path(
            File.join(File.dirname(File.expand_path(__FILE__)), '../')
          )
        end
        
        def appraisal_environment
          @appraisal_environment ||= %r{^.*gemfiles\/(.*)\.gemfile$}.match(
            ENV['BUNDLE_GEMFILE']
          )[1]
        end

        def tmp_dir
          @tmp_dir ||= File.join(application_root, 'tmp')
        end

        def log_dir
          @log_dir ||= File.join(application_root, 'log')
        end

        def pid_dir
          @pid_dir ||= File.join(tmp_dir, 'pids')
        end

        private

        def settings_file_path
          File.join(application_root, 'flapjack-benchmark.yml')
        end  
        
        def load_settings
          raise SettingsFileMissing unless File.exist?(settings_file_path)
          settings = YAML.load_file(settings_file_path)[appraisal_environment]
          raise SettingsDataMissing unless settings
          
          settings
        end
      end
    end
  end
end

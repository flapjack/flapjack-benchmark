require 'config'

module Flapjack
  module Benchmark
    class ServerConfig < Config
      class << self
        def create_config_file!
          FileUtils.mkdir_p(tmp_dir)

          build_method = "build_#{Flapjack::VERSION.tr('.', '_')}_config".to_sym

          if ServerConfig.respond_to?(build_method, true)
            config = ServerConfig.send(build_method)

            file_path = config_file_path
            File.open(file_path, 'w') do |file|
              file.write config
            end

            sleep(3)
            file_path
          else
            raise "Unsupported Flapjack version #{Flapjack::VERSION}"
          end
        end

        def config_file_path
          filename = [config_file_basename, config_file_extension].join('.')
          File.join(tmp_dir, filename)
        end

        private

        def config_file_basename
          # SMELL See above for same pattern - refactor
          "flapjack_#{Flapjack::VERSION.tr('.', '_')}_config"
        end

        def config_file_extension
          Flapjack::VERSION >= '2.0.0' ? 'toml' : 'yaml'
        end

        def build_redis_config
          redis_config = Flapjack::Benchmark::Config.settings['redis']
          {
            'host' => redis_config['host'],
            'port' => redis_config['port'],
            'db' =>   redis_config['db']
          }
        end

        def build_1_6_0_config
          require 'yaml'

          log_file = File.join(log_dir, 'flapjack_1_6.log')

          config = {
            'production' => {
              'pid_dir' => pid_dir,
              'log_dir' => log_dir,
              'daemonize' => 'no',
              'redis' => build_redis_config,
              'processor' => {
                'enabled' => 'yes',
                'queue' => 'events',
                'notifier_queue' => 'notifications',
                'archive_events' => false,
                'events_archive_maxage' => 3600,
                'new_check_scheduled_maintenance_duration' => '0 seconds',
                'logger' => {
                  'level' => 'DEBUG',
                  'syslog_errors' => 'no'
                }
              },
              'gateways' => {
                'jsonapi' => {
                  'enabled' => 'yes',
                  'port' => settings['jsonapi']['port'],
                  'timeout' => 300,
                  'access_log' => log_file,
                  'base_url' => settings['jsonapi']['base_url'],
                  'logger' => {
                    'level' => 'ERROR',
                    'syslog_errors' => 'no'
                  }
                }
              }
            }
          }

          config.to_yaml
        end

        def build_2_0_0_config
          require 'toml'

          # SEMLL Dupey dupe dupe
          log_file = File.join(log_dir, 'flapjack_2_0.log')

          config = {
            'logger' => {
              'file' => log_file,
              'level' => 'ERROR',
              'syslog_errors' => false
            },
            'redis' => build_redis_config,
            'processor' => {
              'enabled' => true,
              'queue' => 'events',
              'notifier_queue' => 'notifications',
              'archive_events' => true,
              'events_archive_maxage' => 10_800,
              'new_check_scheduled_maintenance_duration' => '0 seconds',
              'new_check_scheduled_maintenance_ignore_regex' => 'bypass_ncsm$', # NOTE Not used
              'logger' => {
                'file' => log_file,
                'level' => 'ERROR',
                'syslog_errors' => false
              }
            },
            'notifier' => {
              'enabled' => true,
              'queue' => 'notifications',
              'email_queue' => 'email_notifications',
              'sms_queue' => 'sms_notifications',
              'sms_nexmo_queue' => 'sms_nexmo_notifications',
              'slack_queue' => 'slack_notifications',
              'sms_twilio_queue' => 'sms_twilio_notifications',
              'sms_aspsms_queue' => 'sms_aspsms_notifications',
              'sns_queue' => 'sns_notifications',
              'jabber_queue' => 'jabber_notifications',
              'pagerduty_queue' => 'pagerduty_notifications',
              'default_contact_timezone' => 'UTC',
              'logger' => {
                'file' => log_file,
                'level' => 'INFO',
                'syslog_errors' => true
              }
            },
            'gateways' => {
              'jsonapi' => {
                'enabled' => true,
                'bind_address' => settings['jsonapi']['bind_address'],
                'port' => settings['jsonapi']['port'],
                'timeout' => 300,
                'access_log' => log_file,
                'base_url' => settings['jsonapi']['base_url'],
                'logger' => {
                  'file' => log_file,
                  'level' => 'ERROR',
                  'syslog_errors' => false
                }
              }
            }
          }

          TOML.dump(config)
        end
      end
    end
  end
end

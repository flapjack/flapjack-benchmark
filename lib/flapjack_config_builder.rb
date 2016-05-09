

require 'config'

module Flapjack
  class ConfigBuilder
    
    def self.config_path
      case Flapjack::VERSION
      when '1.6.0' then build_flapjack_1_6_config
      when '2.0.0' then build_flapjack_2_0_config
      else
        raise "Unsupported Flapjack::VERSION #{Flapjack::VERSION}"
      end
    end
    
    private
    
    def self.build_flapjack_2_0_config
      require 'toml'
      
      # SEMLL Dupey dupe dupe
      log_file = File.join(APPLICATION_ROOT, 'log', 'flapjack_2_0.log')
      redis_config = CONFIG['redis']
      jsonapi_config = CONFIG['jsonapi']
      
      
      config = {
        'logger' => {
          'file' => log_file,
          'level' => 'INFO',
          'syslog_errors' => false
        },
        'redis' => {
          'host' => redis_config['host'],
          'port' => redis_config['port'],
          'db' => redis_config['db']
        },
        'processor' => {
          'enabled' => true,
          'queue' => "events",
          'notifier_queue' => "notifications",
          'archive_events' => true,
          'events_archive_maxage' => 10800,
          'new_check_scheduled_maintenance_duration' => "0 seconds",
          'new_check_scheduled_maintenance_ignore_regex' => "bypass_ncsm$", # NOTE Not used
          'logger' => {
            'file' => log_file,
            'level' => "INFO",
            'syslog_errors' => false
          }
        },
        'notifier' => {
          'enabled' => true,
          'queue' => "notifications",
          'email_queue' => "email_notifications",
          'sms_queue' => "sms_notifications",
          'sms_nexmo_queue' => "sms_nexmo_notifications",
          'slack_queue' => "slack_notifications",
          'sms_twilio_queue' => "sms_twilio_notifications",
          'sms_aspsms_queue' => "sms_aspsms_notifications",
          'sns_queue' => "sns_notifications",
          'jabber_queue' => "jabber_notifications",
          'pagerduty_queue' => "pagerduty_notifications",
          'default_contact_timezone' => "UTC",
          'logger' => {
            'file' => log_file,
            'level' => "INFO",
            'syslog_errors' => true
          }
        },
        'gateways' => {
          'jsonapi' => {
            'enabled' => true,
            'bind_address' => jsonapi_config['bind_address'],
            'port' => jsonapi_config['port'],
            'timeout' => 300,
            'access_log' => log_file,
            'base_url' => jsonapi_config['base_url'],
            'logger' => {
              'file' => log_file,
              'level' => "ERROR",
              'syslog_errors' => false
            }
          }
        }
      }
      
      config_file = File.join(APPLICATION_ROOT, 'tmp', 'flapjack_2_0_config.toml')
      
      File.open(config_file, 'w') do |file|
         file.write TOML.dump(config)
      end
      
      config_file
    end
    
    def self.build_flapjack_1_6_config
      require 'yaml'
      
      pid_dir = File.join(APPLICATION_ROOT, 'tmp', 'pids') # SMELL Dupe from flapjack_server.rb
      log_dir = File.join(APPLICATION_ROOT, 'log')
      log_file = File.join(log_dir, 'flapjack_1_6.log')
      
      redis_config = CONFIG['redis']
      jsonapi_config = CONFIG['jsonapi']
      
      config = {      
        'production' => {
          'pid_dir' => pid_dir,
          'log_dir' => log_dir,
          'daemonize' => 'no',
          'redis' => {
            'host' => redis_config['host'],
            'port' => redis_config['port'],
            'db' => redis_config['db']
          },
          'processor' => {
            'enabled' => 'yes',
            'queue' => 'events',
            'notifier_queue' => 'notifications',
            'archive_events' => 'false',
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
               'port' => jsonapi_config['port'],
               'timeout' => 300,
               'access_log' => log_file,
               'base_url' => jsonapi_config['base_url'],
               'logger' => {
                 'level' => 'ERROR',
                 'syslog_errors' => 'no'
               }
            }  
          }
        }
      }
      
      config_file = File.join(APPLICATION_ROOT, 'tmp', 'flapjack_1_6_config.yaml')
      
      File.open(config_file, 'w') do |file|
         file.write config.to_yaml
      end
      
      config_file
    end
  end
end
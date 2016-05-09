require 'yaml'
require 'flapjack/version'

# SMELL Has to be a simpler way to write this
APPLICATION_ROOT = File.expand_path(File.join(File.dirname(File.expand_path(__FILE__)), '../')) unless defined? APPLICATION_ROOT

FLAPJACK_ENV = 'flapjack_' + Flapjack::VERSION.tr('.', '_') unless defined? FLAPJACK_ENV
CONFIG = YAML.load_file(File.join(APPLICATION_ROOT, 'flapjack-benchmark.yml'))[FLAPJACK_ENV] unless defined? CONFIG

# SMELL Need to raise exception if CONFIG is empty
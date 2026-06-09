# frozen_string_literal: true

require "bundler/setup"
require "rspec"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/try"

require "teimas_authentication_system"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
end

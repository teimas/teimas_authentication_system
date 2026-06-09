# frozen_string_literal: true

module TeimasAuthenticationSystem
  module Keycloak
    module UserAttributes
      def self.normalize(raw_attributes)
        return nil if raw_attributes.nil? || raw_attributes.empty?

        result = raw_attributes.each_with_object({}) do |(key, value), attributes|
          string_values = Array(value).map(&:to_s).reject(&:empty?)
          next if string_values.empty?

          attributes[key.to_s] = string_values
        end

        result.empty? ? nil : result
      end
    end
  end
end

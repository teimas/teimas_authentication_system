# frozen_string_literal: true

require "spec_helper"

RSpec.describe TeimasAuthenticationSystem::Keycloak::UserAttributes do
  describe ".normalize" do
    it "returns nil for blank attributes" do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize({})).to be_nil
    end

    it "normalizes scalar and array values to non-empty string arrays" do
      expect(
        described_class.normalize(
          locale: :es,
          flags: [:a, "", "b"],
          ignored_nil: nil,
          ignored_blank: ""
        )
      ).to eq(
        "locale" => ["es"],
        "flags" => ["a", "b"]
      )
    end
  end
end

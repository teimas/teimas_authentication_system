# frozen_string_literal: true

require "spec_helper"

RSpec.describe TeimasAuthenticationSystem::Keycloak::ManagementSystem do
  let(:configuration) { :configuration }
  let(:auth_server_url) { "https://keycloak.example.com" }
  let(:realm) { "realm" }
  let(:client_id) { "client-id" }
  let(:client_secret) { "client-secret" }
  let(:service) { instance_double(described_class::ClientService, access_token: "token") }

  describe ".create_or_update_user!" do
    before do
      allow(described_class::ClientService).to receive(:execute).and_yield(service)
      allow(described_class).to receive(:reset_password!)
      allow(described_class).to receive(:find_clients)
      allow(described_class).to receive(:find_client_role)
      allow(described_class).to receive(:add_client_roles_to_user!)
      allow(described_class).to receive(:find_realm_role)
      allow(described_class).to receive(:add_realm_roles_to_user!)
      allow(described_class).to receive(:find_group)
      allow(described_class).to receive(:add_group_to_user!)
    end

    it "includes attributes when creating a user" do
      allow(described_class).to receive(:find_users).and_return([])

      expect(described_class).to receive(:create_user!).with(
        auth_server_url,
        realm,
        service,
        {
          username: "login@example.com",
          email: "user@example.com",
          firstName: nil,
          lastName: nil,
          enabled: true,
          attributes: { "locale" => ["es"] }
        }
      ).and_return({ "id" => "user-id" })

      result = described_class.create_or_update_user!(
        configuration,
        auth_server_url,
        realm,
        client_id,
        client_secret,
        {
          username: "login@example.com",
          email: "user@example.com",
          attributes: { "locale" => ["es"] }
        }
      )

      expect(result).to eq({ "id" => "user-id" })
    end

    it "resets password when creating a user with password" do
      allow(described_class).to receive(:find_users).and_return([])
      allow(described_class).to receive(:create_user!).and_return({ "id" => "user-id" })

      expect(described_class).to receive(:reset_password!).with(
        auth_server_url,
        realm,
        service,
        "user-id",
        {
          type: "password",
          temporary: true,
          value: "secret"
        }
      )

      described_class.create_or_update_user!(
        configuration,
        auth_server_url,
        realm,
        client_id,
        client_secret,
        {
          username: "login@example.com",
          email: "user@example.com",
          password: "secret"
        }
      )
    end

    it "updates attributes for an existing user without creating or resetting password" do
      existing_user = { "id" => "user-id", "attributes" => { "existing" => ["1"] } }
      updated_user = existing_user.merge("attributes" => { "existing" => ["1"], "locale" => ["es"] })

      allow(described_class).to receive(:find_users).and_return([existing_user])
      allow(described_class).to receive(:update_user!).and_return(updated_user)

      expect(described_class).not_to receive(:create_user!)
      expect(described_class).not_to receive(:reset_password!)
      expect(described_class).to receive(:update_user!).with(
        auth_server_url,
        realm,
        service,
        "user-id",
        {
          "id" => "user-id",
          "attributes" => { "existing" => ["1"], "locale" => ["es"] }
        }
      ).and_return(updated_user)

      result = described_class.create_or_update_user!(
        configuration,
        auth_server_url,
        realm,
        client_id,
        client_secret,
        {
          username: "login@example.com",
          email: "user@example.com",
          password: "secret",
          attributes: { "locale" => ["es"] }
        }
      )

      expect(result).to eq(updated_user)
    end

    it "does not search by email when the username matches" do
      existing_user = { "id" => "user-id" }

      expect(described_class).to receive(:find_users).with(
        auth_server_url,
        realm,
        service,
        { username: "user@example.com" }
      ).and_return([existing_user])

      expect(described_class).not_to receive(:find_users).with(
        auth_server_url,
        realm,
        service,
        { email: "user@example.com" }
      )
      expect(described_class).not_to receive(:create_user!)

      result = described_class.create_or_update_user!(
        configuration,
        auth_server_url,
        realm,
        client_id,
        client_secret,
        {
          username: "user@example.com",
          email: "user@example.com"
        }
      )

      expect(result).to eq(existing_user)
    end

    it "reuses the user found by email when the stored username does not match" do
      existing_user = { "id" => "66882947", "username" => "mcgonzalez" }

      allow(described_class).to receive(:find_users).with(
        auth_server_url,
        realm,
        service,
        { username: "mcgonzalez@sanea2.es" }
      ).and_return([])

      allow(described_class).to receive(:find_users).with(
        auth_server_url,
        realm,
        service,
        { email: "mcgonzalez@sanea2.es" }
      ).and_return([existing_user])

      expect(described_class).not_to receive(:create_user!)

      result = described_class.create_or_update_user!(
        configuration,
        auth_server_url,
        realm,
        client_id,
        client_secret,
        {
          username: "mcgonzalez@sanea2.es",
          email: "mcgonzalez@sanea2.es"
        }
      )

      expect(result).to eq(existing_user)
    end

    it "creates the user when neither the username nor the email match" do
      allow(described_class).to receive(:find_users).with(
        auth_server_url,
        realm,
        service,
        { username: "login@example.com" }
      ).and_return([])

      expect(described_class).to receive(:find_users).with(
        auth_server_url,
        realm,
        service,
        { email: "user@example.com" }
      ).and_return([])

      expect(described_class).to receive(:create_user!).and_return({ "id" => "user-id" })

      result = described_class.create_or_update_user!(
        configuration,
        auth_server_url,
        realm,
        client_id,
        client_secret,
        {
          username: "login@example.com",
          email: "user@example.com"
        }
      )

      expect(result).to eq({ "id" => "user-id" })
    end

    it "raises when the email matches more than one user" do
      allow(described_class).to receive(:find_users).with(
        auth_server_url,
        realm,
        service,
        { username: "mcgonzalez@sanea2.es" }
      ).and_return([])

      allow(described_class).to receive(:find_users).with(
        auth_server_url,
        realm,
        service,
        { email: "mcgonzalez@sanea2.es" }
      ).and_return([{ "id" => "first-id" }, { "id" => "second-id" }])

      expect(described_class).not_to receive(:create_user!)
      expect(described_class).not_to receive(:update_user!)

      expect do
        described_class.create_or_update_user!(
          configuration,
          auth_server_url,
          realm,
          client_id,
          client_secret,
          {
            username: "mcgonzalez@sanea2.es",
            email: "mcgonzalez@sanea2.es",
            attributes: { "locale" => ["es"] }
          }
        )
      end.to raise_error(TeimasAuthenticationSystem::AmbiguousKeycloakUserError, /mcgonzalez@sanea2\.es/)
    end

    it "propagates search failures instead of creating a duplicated user" do
      allow(described_class).to receive(:find_users).and_raise(RestClient::Forbidden)

      expect(described_class).not_to receive(:create_user!)

      expect do
        described_class.create_or_update_user!(
          configuration,
          auth_server_url,
          realm,
          client_id,
          client_secret,
          {
            username: "login@example.com",
            email: "user@example.com"
          }
        )
      end.to raise_error(RestClient::Forbidden)
    end
  end

  describe ".find_users" do
    it "propagates search errors instead of returning nil" do
      allow(RestClient).to receive(:get).and_raise(RestClient::Forbidden)

      expect do
        described_class.send(:find_users, auth_server_url, realm, service, { username: "login@example.com" })
      end.to raise_error(RestClient::Forbidden)
    end
  end

  describe ".update_user!" do
    let(:user_data) do
      {
        "id" => "user-id",
        "email" => "user@example.com",
        "firstName" => "Ada",
        "lastName" => "Lovelace",
        "attributes" => { "existing" => ["1"] }
      }
    end

    it "updates only attributes for an existing user" do
      response = instance_double("RestClient::Response", body: "")
      allow(response).to receive(:return!).and_return(response)

      expect(RestClient).to receive(:put) do |url, body, headers, &block|
        expect(url).to eq("https://keycloak.example.com/admin/realms/realm/users/user-id")
        expect(headers["Authorization"]).to eq("Bearer token")

        payload = JSON.parse(body)
        expect(payload["id"]).to eq("user-id")
        expect(payload["email"]).to eq("user@example.com")
        expect(payload["firstName"]).to eq("Ada")
        expect(payload["lastName"]).to eq("Lovelace")
        expect(payload["attributes"]).to eq(
          "existing" => ["1"],
          "locale" => ["es"]
        )

        block.call(response, nil, nil)
      end

      result = described_class.send(
        :update_user!,
        auth_server_url,
        realm,
        service,
        "user-id",
        user_data.merge("attributes" => { "existing" => ["1"], "locale" => ["es"] })
      )

      expect(result["attributes"]).to eq(
        "existing" => ["1"],
        "locale" => ["es"]
      )
    end

    it "propagates update errors" do
      allow(RestClient).to receive(:put).and_raise(StandardError, "boom")

      expect do
        described_class.send(
          :update_user!,
          auth_server_url,
          realm,
          service,
          "user-id",
          user_data
        )
      end.to raise_error(StandardError, "boom")
    end
  end
end

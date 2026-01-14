require "test_helper"

class OidcAuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:oidc] = nil
  end

  test "complete OIDC sign in flow for new user" do
    auth_hash = OmniAuth::AuthHash.new(
      provider: "oidc",
      uid: "cory-123",
      info: { email: "cory@73signals.com", name: "Cory" },
      extra: { raw_info: { email_verified: true } }
    )

    OmniAuth.config.mock_auth[:oidc] = auth_hash

    untenanted do
      # Visit login page
      get new_session_path
      assert_response :success

      # Simulate OIDC callback (in real flow, user would click button,
      # get redirected to provider, then redirected back to callback)
      post "/auth/oidc/callback", env: { "omniauth.auth" => auth_hash }

      assert_response :redirect
      assert cookies[:session_token].present?

      # Verify identity was created
      identity = Identity.find_by(email_address: "cory@73signals.com")
      assert identity.present?
      assert_equal "cory-123", identity.oidc_subject
      assert_equal "oidc", identity.oidc_provider
    end
  end

  test "OIDC sign in links to existing magic link user" do
    existing = identities(:david)
    original_count = Identity.count

    auth_hash = OmniAuth::AuthHash.new(
      provider: "oidc",
      uid: "link-789",
      info: { email: existing.email_address, name: "David" },
      extra: { raw_info: { email_verified: true } }
    )

    OmniAuth.config.mock_auth[:oidc] = auth_hash

    untenanted do
      post "/auth/oidc/callback", env: { "omniauth.auth" => auth_hash }

      assert_response :redirect
      assert cookies[:session_token].present?

      # Should NOT create new identity, should link to existing
      assert_equal original_count, Identity.count

      existing.reload
      assert_equal "link-789", existing.oidc_subject
      assert_equal "oidc", existing.oidc_provider
    end
  end

  test "OIDC user can sign in multiple times" do
    existing = identities(:mike)
    auth_hash = OmniAuth::AuthHash.new(
      provider: "oidc",
      uid: "repeat-user",
      info: { email: existing.email_address, name: "Mike" },
      extra: { raw_info: { email_verified: true } }
    )

    OmniAuth.config.mock_auth[:oidc] = auth_hash

    first_session_token = nil
    second_session_token = nil

    untenanted do
      # First sign in
      post "/auth/oidc/callback", env: { "omniauth.auth" => auth_hash }
      assert_response :redirect
      first_session_token = cookies[:session_token]
      assert first_session_token.present?

      # Clear cookies manually for test
      cookies.delete(:session_token)

      # Second sign in
      post "/auth/oidc/callback", env: { "omniauth.auth" => auth_hash }
      assert_response :redirect
      second_session_token = cookies[:session_token]
      assert second_session_token.present?

      # Should have created two separate sessions
      assert_not_equal first_session_token, second_session_token
    end
  end
end

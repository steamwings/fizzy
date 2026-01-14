require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "send_magic_link" do
    identity = identities(:david)

    assert_emails 1 do
      magic_link = identity.send_magic_link
      assert_not_nil magic_link
      assert_equal identity, magic_link.identity
    end
  end

  test "email address format validation" do
    invalid_emails = [
      "sam smith@example.com",       # space in local part
      "@example.com",                # missing local part
      "test@",                       # missing domain
      "test",                        # missing @ and domain
      "<script>@example.com",        # angle brackets
      "test@example.com\nX-Inject:" # newline (header injection attempt)
    ]

    invalid_emails.each do |email|
      identity = Identity.new(email_address: email)
      assert_not identity.valid?, "expected #{email.inspect} to be invalid"
      assert identity.errors[:email_address].any?, "expected error on email_address for #{email.inspect}"
    end
  end

  test "join" do
    identity = identities(:david)
    account = accounts(:initech)

    Current.without_account do
      assert_difference "User.count", 1 do
        identity.join(account)
      end

      user = account.users.find_by!(identity: identity)

      assert_not_nil user
      assert_equal identity, user.identity
      assert_equal identity.email_address, user.name
    end
  end

  test "destroy deactivates users before nullifying identity" do
    identity = identities(:kevin)
    user = users(:kevin)

    assert_predicate user, :active?
    assert_predicate user.accesses, :any?

    identity.destroy!
    user.reload

    assert_nil user.identity_id, "identity should be nullified"
    assert_not_predicate user, :active?
    assert_empty user.accesses, "user accesses should be removed"
  end

  test "find_or_create_from_oidc creates new identity" do
    auth_hash = build_oidc_auth_hash(
      uid: "new-user-123",
      email: "newoidc@example.com"
    )

    identity = Identity.find_or_create_from_oidc(auth_hash)

    assert identity.persisted?
    assert_equal "newoidc@example.com", identity.email_address
    assert_equal "new-user-123", identity.oidc_subject
    assert_equal "oidc", identity.oidc_provider
  end

  test "find_or_create_from_oidc links to existing identity by email" do
    existing = identities(:david)

    auth_hash = build_oidc_auth_hash(
      uid: "link-123",
      email: existing.email_address
    )

    identity = Identity.find_or_create_from_oidc(auth_hash)

    assert_equal existing.id, identity.id
    assert_equal "link-123", identity.oidc_subject
  end

  test "find_or_create_from_oidc finds by oidc_subject" do
    existing = identities(:oidc_user)

    auth_hash = build_oidc_auth_hash(
      uid: existing.oidc_subject,
      email: "different@example.com", # Different email
      email_verified: false
    )

    identity = Identity.find_or_create_from_oidc(auth_hash)

    assert_equal existing.id, identity.id
    # Email should NOT change if not verified
    assert_equal existing.email_address, identity.email_address
  end

  test "find_or_create_from_oidc updates email when verified" do
    existing = identities(:oidc_user)
    new_email = "updated@example.com"

    auth_hash = build_oidc_auth_hash(
      uid: existing.oidc_subject,
      email: new_email,
      email_verified: true
    )

    identity = Identity.find_or_create_from_oidc(auth_hash)

    assert_equal existing.id, identity.id
    assert_equal new_email, identity.email_address
  end

  test "authenticated_via_oidc? returns true for OIDC identities" do
    assert identities(:oidc_user).authenticated_via_oidc?
    assert_not identities(:david).authenticated_via_oidc?
  end

  private
    def build_oidc_auth_hash(uid:, email:, email_verified: true, name: "Test User")
      OmniAuth::AuthHash.new(
        provider: "oidc",
        uid: uid,
        info: { email: email, name: name },
        extra: { raw_info: { email_verified: email_verified } }
      )
    end
end

module Identity::OidcCompatible
  extend ActiveSupport::Concern

  class_methods do
    def find_or_create_from_oidc(auth_hash)
      provider = auth_hash.provider
      subject = auth_hash.uid
      email = auth_hash.info.email
      email_verified = auth_hash.extra.raw_info.email_verified || false

      # Validate required fields
      return new unless subject.present? && email.present?

      # First, try to find existing identity by OIDC subject
      identity = find_by(oidc_subject: subject, oidc_provider: provider)

      if identity
        # Update email if verified and changed
        if email_verified && identity.email_address != email
          identity.update(email_address: email, oidc_email_verified: true)
        end
        return identity
      end

      identity = find_by(email_address: email)

      if identity
        identity.update(
          oidc_subject: subject,
          oidc_provider: provider,
          oidc_email_verified: email_verified
        )
        return identity
      end

      create(
        email_address: email,
        oidc_subject: subject,
        oidc_provider: provider,
        oidc_email_verified: email_verified
      )
    rescue ActiveRecord::RecordNotUnique
      retry
    end
  end

  def authenticated_via_oidc?
    oidc_subject.present?
  end
end

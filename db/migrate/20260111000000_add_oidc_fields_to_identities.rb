class AddOidcFieldsToIdentities < ActiveRecord::Migration[8.2]
  def change
    add_column :identities, :oidc_subject, :string
    add_column :identities, :oidc_provider, :string
    add_column :identities, :oidc_email_verified, :boolean, default: false

    add_index :identities, [:oidc_subject, :oidc_provider],
      unique: true,
      name: "index_identities_on_oidc_subject_and_provider"
  end
end

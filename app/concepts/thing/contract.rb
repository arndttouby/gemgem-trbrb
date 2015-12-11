module Thing::Contract
  class Create < Reform::Form
    model Thing
    feature Disposable::Twin::Persisted

    property :name
    property :description

    validates :name, presence: true
    validates :description, length: {in: 4..160}, allow_blank: true

    # FIXME: why does the contract need the writer extended?
    property :file, virtual: true
      property :image_meta_data, deserializer: {writeable: false} # FIXME.

      validates :file, file_size: { less_than: 1.megabyte },
        file_content_type: { allow: ['image/jpeg', 'image/png'] }

    collection :users,
        prepopulator:      :prepopulate_users!,
        populate_if_empty: :populate_users!,
        skip_if:           :all_blank do

      property :email
      property :remove, virtual: true
      validates :email, presence: true, email: true
      validate :authorship_limit_reached?

      def readonly? # per form.
        model.persisted?
      end
      alias_method :removeable?, :readonly?

    private
      def authorship_limit_reached?
        return if model.authorships.find_all { |au| au.confirmed == 0 }.size < 5
        errors.add("user", "This user has too many unconfirmed authorships.")
      end
    end
    validates :users, length: {maximum: 3}

  private
    def prepopulate_users!(options)
      (3 - users.size).times { users << User.new }
    end

    def populate_users!(fragment:, **)
      User.find_by_email(fragment["email"]) or User.new
    end
  end

  class Update < Create
    property :name, writeable: false

    # DISCUSS: should inherit: true be default?
    collection :users, inherit: true, populator: :user! do
      property :email, skip_if: :skip_email?

      def skip_email?(fragment, options)
        model.persisted?
      end
    end

  private
    def user!(fragment:, index:, **)
      # don't process if it's getting removed!
      if fragment["remove"] == "1"
        deserialized_user = users.find { |u| u.id.to_s == fragment["id"] }
        users.delete(deserialized_user)
        return Representable::Pipeline::Stop
      end

      # skip if already existing
      return Representable::Pipeline::Stop if users[index]

      users.insert(index, User.new)
    end
  end
end
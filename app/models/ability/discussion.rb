module Ability::Discussion
  def initialize(user)
    super(user)

    can [:show,
         :print,
         :dismiss,
         :subscribe_to], ::Discussion do |discussion|
      # do we want to support having a discussion_reader_token but not being logged in yet?
      Queries::VisibleDiscussions.new(user: user, show_public: true).include?(discussion)
    end

    can [:mark_as_read, :mark_as_seen], ::Discussion do |discussion|
      user.is_logged_in? && can?(:show, discussion)
    end

    can :update_version, ::Discussion do |discussion|
      discussion.author == user or discussion.admins.include?(user)
    end

    can :create, ::Discussion do |discussion|
      user.email_verified? &&
      (discussion.admins.include?(user) ||
      (discussion.group && discussion.group.members_can_start_discussions? && discussion.members.include?(user)))
    end

    can [:announce], ::Discussion do |discussion|
      user.email_verified? &&
      (discussion.admins.include?(user) || (discussion.group.members_can_announce? && discussion.members.include?(user)))
    end

    can [:update], ::Discussion do |discussion|
      user.email_verified? &&
      (discussion.author == user ||
      discussion.admins.include?(user) ||
      (discussion.group.members_can_edit_discussions? && discussion.members.include?(user)))
    end

    can :pin, ::Discussion do |discussion|
      discussion.admins.include?(user)
    end

    can [:destroy, :move, :move_comments], ::Discussion do |discussion|
      discussion.author == user or discussion.admins.include?(user)
    end

    can :fork, ::Discussion do |discussion|
      Event.where(id: discussion.forked_event_ids).pluck(:discussion_id).uniq.length == 1 &&
      can?(:move, Event.find(discussion.forked_event_ids.last).discussion) &&
      can?(:move, discussion)
    end

    can [:set_volume,
         :show_description_history,
         :preview_version,
         :make_draft], ::Discussion do |discussion|
      discussion.members.include?(user)
    end

    can :remove_events, ::Discussion do |discussion|
      discussion.author == user or discussion.admins.include?(user)
    end

    can :start_poll, ::Discussion do |discussion|
      can?(:start_poll, discussion.group) || discussion.admins.include?(user)
    end
  end
end

import BaseModel    from '@/shared/record_store/base_model'
import AppConfig    from '@/shared/services/app_config'
import HasDocuments from '@/shared/mixins/has_documents'
import HasTranslations  from '@/shared/mixins/has_translations'

export default class GroupModel extends BaseModel
  @singular: 'group'
  @plural: 'groups'
  @uniqueIndices: ['id', 'key']
  @indices: ['parentId']
  @draftParent: 'draftParent'
  @draftPayloadAttributes: ['name', 'description']

  draftParent: ->
    @parent() or @recordStore.users.find(AppConfig.currentUserId)

  defaultValues: ->
    parentId: null
    name: ''
    description: ''
    descriptionFormat: 'html'
    groupPrivacy: 'closed'
    discussionPrivacyOptions: 'private_only'
    membershipGrantedUpon: 'approval'
    membersCanAnnounce: true
    membersCanAddMembers: true
    membersCanEditDiscussions: true
    membersCanEditComments: true
    membersCanRaiseMotions: true
    membersCanVote: true
    membersCanStartDiscussions: true
    membersCanCreateSubgroups: false
    motionsCanBeEdited: false
    files: []
    imageFiles: []
    attachments: []

  afterConstruction: ->
    if @privacyIsClosed()
      @allowPublicThreads = @discussionPrivacyOptions == 'public_or_private'
    HasDocuments.apply @, showTitle: true
    HasTranslations.apply @

  relationships: ->
    @hasMany 'discussions'
    @hasMany 'polls'
    @hasMany 'membershipRequests'
    @hasMany 'memberships'
    @hasMany 'groupIdentities'
    @hasMany 'allDocuments', from: 'documents', with: 'groupId', of: 'id'
    @hasMany 'subgroups', from: 'groups', with: 'parentId', of: 'id', orderBy: 'name'
    @belongsTo 'parent', from: 'groups'

  activeMemberships: ->
    _.filter @memberships(), (m) -> m.acceptedAt

  activeMembershipsCount: ->
    @membershipsCount - @pendingMembershipsCount

  pendingMemberships: ->
    _.filter @memberships(), (m) -> !m.acceptedAt

  hasRelatedDocuments: ->
    @hasDocuments() or @allDocuments().length > 0

  parentOrSelf: ->
    if @isParent() then @ else @parent()

  group: -> @

  fetchToken: ->
    @remote.getMember(@id, 'token').then => @token

  resetToken: ->
    @remote.postMember(@id, 'reset_token').then => @token

  closedPolls: ->
    _.filter @polls(), (poll) ->
      !poll.isActive()

  activePolls: ->
    _.filter @polls(), (poll) ->
      poll.isActive()

  pendingMembershipRequests: ->
    _.filter @membershipRequests(), (membershipRequest) ->
      membershipRequest.isPending()

  hasPendingMembershipRequests: ->
    _.some @pendingMembershipRequests()

  hasPendingMembershipRequestFrom: (user) ->
    _.some @pendingMembershipRequests(), (request) ->
      request.requestorId == user.id

  previousMembershipRequests: ->
    _.filter @membershipRequests(), (membershipRequest) ->
      !membershipRequest.isPending()

  hasPreviousMembershipRequests: ->
    _.some @previousMembershipRequests()

  pendingInvitations: ->
    _.filter @invitations(), (invitation) ->
      invitation.isPending() and invitation.singleUse

  hasPendingInvitations: ->
    _.some @pendingInvitations()

  hasSubgroups: ->
    @isParent() && @subgroups().length

  organisationDiscussions: ->
    @recordStore.discussions.find(groupId: { $in: @organisationIds() }, discussionReaderId: { $ne: null })

  publicOrganisationIds: ->
    _.map(_.filter(@subgroups().concat(@), (group) -> group.groupPrivacy == 'open'), 'id')

  organisationIds: ->
    _.map(@subgroups(), 'id').concat(@id)

  membershipFor: (user) ->
    _.find @memberships(), (membership) -> membership.userId == user.id

  members: ->
    @recordStore.users.find(id: {$in: @memberIds()})

  adminMemberships: ->
    _.filter @memberships(), (membership) -> membership.admin

  admins: ->
    adminIds = _.map(@adminMemberships(), (membership) -> membership.userId)
    @recordStore.users.find(id: {$in: adminIds})

  coordinatorsIncludes: (user) ->
    _.some @recordStore.memberships.where(groupId: @id, userId: user.id)

  memberIds: ->
    _.map @memberships(), 'userId'

  adminIds: ->
    _.map @adminMemberships(), 'userId'

  parentName: ->
    @parent().name if @parent()?

  privacyIsOpen: ->
    @groupPrivacy == 'open'

  privacyIsClosed: ->
    @groupPrivacy == 'closed'

  privacyIsSecret: ->
    @groupPrivacy == 'secret'

  isSubgroup: ->
    @parentId?

  isArchived: ->
    @archivedAt?

  isParent: ->
    !@parentId?

  logoUrl: ->
    if @logoUrlMedium
      @logoUrlMedium
    else if @isSubgroup()
      @parent().logoUrl()
    else
      AppConfig.theme.icon_src

  coverUrl: (size = 'large') ->
    if @isSubgroup() && !@hasCustomCover
      @parent().coverUrl(size)
    else
      @coverUrls[size]

  archive: =>
    @remote.patchMember(@key, 'archive').then =>
      @remove()
      _.each @memberships(), (m) -> m.remove()

  export: =>
    @remote.postMember(@id, 'export')

  uploadLogo: (file) =>
    @remote.upload("#{@key}/upload_photo/logo", file, {}, ->)

  uploadCover: (file) =>
    @remote.upload("#{@key}/upload_photo/cover_photo", file, {}, ->)

  hasSubscription: ->
    @subscriptionKind?

  isSubgroupOfSecretParent: ->
    @isSubgroup() && @parent().privacyIsSecret()

  groupIdentityFor: (type) ->
    _.find @groupIdentities(), (gi) ->
      gi.userIdentity().identityType == type

  targetModel: ->
    @recordStore.discussions.find(guestGroupId: @id)[0] or
    @recordStore.polls.find(guestGroupId: @id)[0] or
    @

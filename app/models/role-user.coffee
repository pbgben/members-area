async = require 'async'
_ = require 'underscore'

module.exports = (db, models) ->
  RoleUser = db.define 'role_user', {
    id:
      type: 'number'
      serial: true
      primary: true

    role_id:
      type: 'number'
      required: true

    user_id:
      type: 'number'
      required: true

    approved:
      type: 'date'
      required: false

    rejected:
      type: 'date'
      required: false

    meta:
      type: 'object'
      required: true
      defaultValue: {}
  },
    timestamp: true
    hooks: db.applyCommonHooks
      beforeCreate: (next) ->
        return next() if @approved?
        @getRole (err, role) =>
          return next err if err
          userId = @user_id
          baseRoleId = 1
          ownerRoleId = 2
          if userId is 1 and role.id in [baseRoleId, ownerRoleId]
            @approved = new Date()
            return next()
          # Should we auto-grant this role?
          @_shouldAutoApprove (autoApprove) =>
            if autoApprove
              @approved = new Date()
            next()

    methods:
      approve: (user, roleId, callback) ->
        approvals = @meta.approvals
        approvals ?= {}
        approvals[roleId] ?= []
        if approvals[roleId].indexOf(user.id) is -1
          approvals[roleId].push user.id
          @setMeta approvals:approvals
          @save callback
        else
          callback()

      getRequirementsWithStatus: (callback) ->
        @getRole (err, role) =>
          return callback err if err
          requirements = role.meta.requirements
          checkRequirement = (requirement, next) =>
            @_checkRequirement requirement, (err) =>
              next null, _.extend requirement,
                passed: !err?
          async.map requirements, checkRequirement, callback

      _shouldAutoApprove: (callback) ->
        @getRole (err, role) =>
          return callback false unless role
          requirements = role.meta.requirements ? []
          async.map requirements, @_checkRequirement.bind(this), (err) ->
            callback !err

      _checkRequirement: (requirement, callback) ->
        models = require('./')
        switch requirement.type
          when 'text'
            process.nextTick callback
          when 'role'
            @getUser (err, user) =>
              return callback err if err
              return callback new Error "User not found" unless user?
              user.hasActiveRole requirement.roleId, (hasRole = false) ->
                return callback new Error "Nope" unless hasRole
                callback()
          when 'approval'
            {roleId, count} = requirement
            approvals = @meta.approvals?[roleId]
            approvals ?= []
            count -= approvals.length
            process.nextTick ->
              return callback "#{count} more approvals for role '#{roleId}' required" if count > 0
              callback()
          else
            console.error "Requirement type '#{requirement.type}' not known."
            process.nextTick ->
              callback "Unknown"

  RoleUser.modelName = 'RoleUser'
  return RoleUser

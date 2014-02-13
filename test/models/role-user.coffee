{Sequelize, sequelize, Role, User, RoleUser, expect, models, sinon, catchErrors} = require '../test_helper'

describe RoleUser.name, ->
  before ->
    @user = User.build(
      id:6
      email:"example@example.com"
      username: "example"
      password: "s3krit!!"
    )

  before ->
    @role = Role.build(
      id: 11
      name: 'Arbitrary'
      meta:
        requirements: [
          {
            type: 'text'
            text: "Arbitrary"
          }
        ]
    )
    Role.roles = [@role]

  describe 'requirements', ->
    it 'passes text', (done) ->
      roleUser = RoleUser.build()
      roleUser.checkRequirement {type: 'text', text: 'Arbitrary'}, (err) ->
        expect(err).to.not.exist
        done()

    it 'passes role if user has role', (done) ->
      sinon.stub @user, "hasActiveRole", (_role) =>
        promise = new Sequelize.Utils.CustomEventEmitter catchErrors done, (emitter) =>
          expect(_role?.id).to.equal @role.id
          emitter.emit 'success', true
        return promise.run()
      roleUser = RoleUser.build(UserId:@user.id, RoleId:@role.id)
      sinon.stub roleUser, "getUser", =>
        promise = new Sequelize.Utils.CustomEventEmitter (emitter) =>
          emitter.emit 'success', @user
        return promise.run()
      roleUser.checkRequirement {type: 'role', roleId: @role.id}, catchErrors done, (err) =>
        expect(err).to.not.exist
        @user.hasActiveRole.restore()
        done()

    it 'fails role if user hasn\'t role', (done) ->
      stub = sinon.stub @user, "hasActiveRole", (_role) =>
        promise = new Sequelize.Utils.CustomEventEmitter catchErrors done, (emitter) =>
          expect(_role.id).to.equal @role.id
          emitter.emit 'success', false
        return promise.run()
      roleUser = RoleUser.build(UserId:@user.id, RoleId:@role.id)
      sinon.stub roleUser, "getUser", =>
        promise = new Sequelize.Utils.CustomEventEmitter (emitter) =>
          emitter.emit 'success', @user
        return promise.run()
      roleUser.checkRequirement {type: 'role', roleId: @role.id}, (err) =>
        expect(err).to.exist
        @user.hasActiveRole.restore()
        done()

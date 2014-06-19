eventric = require 'eventric'

describe 'Command Aggregate Feature', ->

  eventStoreMock = null
  beforeEach ->
    eventStoreMock =
      find: sandbox.stub().yields null, []
      save: sandbox.stub().yields null

  describe 'given we created and initialized some example bounded context including an aggregate', ->
    exampleContext = null
    beforeEach ->
      exampleContext = eventric.boundedContext 'exampleContext'
      exampleContext.set 'store', eventStoreMock
      exampleContext.addAggregate 'Example', class Example


    describe 'when we command the bounded context to command an aggregate', ->
      beforeEach ->
        eventStoreMock.find.yields null, [
          name: 'ExampleCreated'
          aggregate:
            id: 1
            name: 'Example'
        ]

        class SomethingHappened
          constructor: (params) ->
            @someId   = params.someId
            @rootProp = params.rootProp
            @entity   = params.entity

        exampleContext.addDomainEvent 'SomethingHappened', SomethingHappened

        class ExampleEntity
          someEntityFunction: ->
            @entityProp = 'bar'

        class ExampleRoot
          doSomething: (someId) ->
            entity = new ExampleEntity
            entity.someEntityFunction()

            @$raiseDomainEvent 'SomethingHappened',
              someId: someId
              rootProp: 'foo'
              entity: entity

          handleExampleCreated: ->
            @entities = []

          handleSomethingHappened: (domainEvent) ->
            @someId = domainEvent.payload.someId
            @rootProp = domainEvent.payload.rootProp
            @entities[2] = domainEvent.payload.entity


        exampleContext.addAggregate 'Example', ExampleRoot

        exampleContext.addCommands
          someBoundedContextFunction: (params, callback) ->
            @$aggregate.command
              id: params.id
              name: 'Example'
              methodName: 'doSomething'
              methodParams: [1]
            .then =>
              callback null


      it 'then it should have triggered the correct DomainEvent', (done) ->
        exampleContext.addDomainEventHandler 'SomethingHappened', (domainEvent) ->
          expect(domainEvent.payload.entity.entityProp).to.equal 'bar'
          expect(domainEvent.name).to.equal 'SomethingHappened'
          done()

        exampleContext.initialize()
        exampleContext.command
          name: 'someBoundedContextFunction'
          params:
            id: 1

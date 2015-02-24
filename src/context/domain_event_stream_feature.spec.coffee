describe 'Domain Event Stream Feature', ->

  describe 'given we created and initialized a context with two aggregates', ->
    exampleContext = null
    beforeEach ->
      class Example
        create: ->
          @$emitDomainEvent 'ExampleCreated'

      class AnotherExample
        create: ->
          @$emitDomainEvent 'AnotherExampleCreated'

      exampleContext = eventric.context 'exampleContext'
        .defineDomainEvents
          ExampleCreated: ->
          AnotherExampleCreated: ->
        .addAggregates
          Example: Example
          AnotherExample: AnotherExample

      exampleContext.addCommandHandlers
        CreateExample: (params) ->
          exampleId = null
          @$aggregate.create 'Example'
          .then (example) ->
            example.$save()

        CreateAnotherExample: (params) ->
          anotherExampleId = null
          @$aggregate.create 'AnotherExample'
          .then (anotherExample) ->
            anotherExample.$save()


    describe 'and an according domain event stream and projection', ->
      projectionId = null
      beforeEach (done) ->
        exampleContext.addDomainEventStream 'ExampleStream', ->
          filterExampleCreated: ->
            false

          filterAnotherExampleCreated: ->
            true

        exampleContext.addProjection 'ExampleProjection', ->
          initialize: (params, done) ->
            @$subscribeToDomainEventStream 'ExampleStream'
            done()

          handleExampleCreated: ->
            @created = true

          handleAnotherExampleCreated: ->
            @anotherCreated = true

        exampleContext.initialize()
        .then ->
          exampleContext.initializeProjectionInstance 'ExampleProjection'
          .then (_projectionId) ->
            projectionId = _projectionId
            done()


      describe 'when we send a command which generates domain events in two aggregates', ->
        it 'then the domain event stream should publish the correct domain events', (done) ->
          exampleContext.subscribe "projection:#{projectionId}:changed", (event) ->
            expect(event.projection.created).to.be.undefined
            expect(event.projection.anotherCreated).to.be.true
            done()

          exampleContext.command 'CreateExample'
          .then ->
            exampleContext.command 'CreateAnotherExample'
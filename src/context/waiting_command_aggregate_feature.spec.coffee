describe 'Waiting Command Aggregate Feature', ->

  describe 'given we created and initialized a context with an aggregate', ->
    exampleContext = null
    beforeEach ->
      class Example
        create: ->
          @$emitDomainEvent 'ExampleCreated'
        handleExampleCreated: (domainEvent) ->

      exampleContext = eventric.context 'exampleContext'
      exampleContext.defineDomainEvent 'ExampleCreated', ->
      exampleContext.addAggregate 'Example', Example

      exampleContext.addCommandHandlers
        CreateExample: (params) ->
          exampleId = null
          @$aggregate.create 'Example'
          .then (example) =>
            example.$save()

      exampleContext.enableWaitingMode()


    describe 'and an according projection and query handler', ->
      beforeEach (done) ->
        exampleContext.addProjection 'ExampleProjection', ->
          stores: ['inmemory']

          handleExampleCreated: (domainEvent, promise) ->
            setTimeout =>
              @$store.inmemory.exampleCreated = true
              promise.resolve()
            , 500

        exampleContext.addQueryHandler 'getExample', (params) ->
          @$projectionStore 'inmemory', 'ExampleProjection'
        exampleContext.initialize()
        .then ->
          done()


      describe 'when we enable waiting mode and send a command', ->
        it 'should wait for the projection to be updated before returning from the command', (done) ->
          exampleContext.command 'CreateExample', {}
          .then ->
            exampleContext.query 'getExample', {}
          .then (projectionStore) ->
            setTimeout ->
              expect(projectionStore.exampleCreated).to.be.true
              done()
            , 0


    describe 'and an async domain event handler', ->

      asyncOperation = null

      beforeEach (done) ->
        asyncOperation = sandbox.spy()
        handler = (domainEvent, done) ->
          setTimeout ->
            asyncOperation()
            done()
          , 500
        exampleContext.subscribeToDomainEvent 'ExampleCreated', handler, isAsync: true

        exampleContext.initialize()
        .then ->
          done()


      describe 'when we enable waiting mode and send a command', ->

        it 'should wait for the domain event handler to be finished before returning from the command', (done) ->
          exampleContext.command 'CreateExample', {}
          .then ->
            setTimeout ->
              expect(asyncOperation).to.have.been.called
              done()
            , 0
describe 'Projection Feature', ->

  describe 'given we created and initialized some example context including a Projection', ->
    exampleContext = null
    beforeEach (done) ->
      exampleContext = eventric.context 'exampleContext'

      exampleContext.addDomainEvents
        ExampleCreated: ->

        SomethingHappened: (params) ->
          @specific = params.whateverFoo

      exampleContext.addProjection 'ExampleProjection', ->
        initialize: (done) ->
          @$projectionStore 'ExampleProjection', (err, projectionStore) =>
            @inmemory = projectionStore
            done()
        handleSomethingHappened: (domainEvent, done) ->
          @inmemory.totallyDenormalized = domainEvent.payload.specific
          done()

      exampleContext.addAggregate 'Example', ->
        handleExampleCreated: (domainEvent) ->
          @whatever = 'bar'
        doSomething: ->
          if @whatever is 'bar'
            @$emitDomainEvent 'SomethingHappened', whateverFoo: 'foo'
        handleSomethingHappened: (domainEvent) ->
          @whatever = domainEvent.payload.whateverFoo

      exampleContext.addCommandHandler 'doSomethingWithExample', (params, callback) ->
        @$repository('Example').findById params.id
        .then (example) =>
          example.doSomething()
          @$repository('Example').save params.id
        .then =>
          callback()

      exampleContext.initialize =>
        store = exampleContext.getStore()
        sandbox.stub store, 'find'
        store.find.yields null, [
          name: 'ExampleCreated'
          aggregate:
            id: 1
            name: 'Example'
        ]
        done()


    describe 'when DomainEvents got emitted which the Projection subscribed to', ->
      it 'then the Projection should call the projectionStore with the denormalized state', (done) ->
        exampleContext.command 'doSomethingWithExample', id: 1
        .then ->
          exampleContext.projectionStore 'ExampleProjection', (err, projectionStore) ->
            expect(projectionStore).to.deep.equal totallyDenormalized: 'foo'
            done()
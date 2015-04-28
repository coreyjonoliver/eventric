describe 'Projection Feature', ->

  describe 'given an example context with one aggregate with two simple commands', ->
    exampleContext = null
    beforeEach ->
      exampleContext = eventric.context 'exampleContext'

      exampleContext.defineDomainEvents
        ExampleCreated: (params) ->
          @specific = params.specific


        ExampleModified: (params) ->
          @specific = params.specific


      exampleContext.addAggregate 'Example', ->
        create: ->
          @$emitDomainEvent 'ExampleCreated',
            specific: 'created'
        modify: ->
          @$emitDomainEvent 'ExampleModified',
            specific: 'modified'


      exampleContext.addCommandHandlers
        CreateExample: (params) ->
          exampleId = null
          @$aggregate.create 'Example'
          .then (example) ->
            example.$save()

        ModifyExample: (params) ->
          @$aggregate.load 'Example', params.id
          .then (example) ->
            example.modify()
            example.$save()


    describe 'given a projection added to it', ->

      beforeEach ->
        exampleContext.addProjection 'ExampleProjection', ->
          stores: ['inmemory']

          handleExampleCreated: (domainEvent) ->
            @$store.inmemory.exampleCreated = domainEvent.payload.specific


          handleExampleModified: (domainEvent) ->
            @$store.inmemory.exampleModified = domainEvent.payload.specific


        exampleContext.initialize()


      describe 'when emitting domain events the projection subscribed to', ->

        it 'should execute the projection\'s event handlers and save it to the specified store', ->
          exampleContext.command 'CreateExample'
          .then (exampleId) ->
            exampleContext.command 'ModifyExample', id: exampleId
          .then ->
            exampleContext.getProjectionStore 'inmemory', 'ExampleProjection'
            .then (projectionStore) ->
              expect(projectionStore.exampleCreated).to.equal 'created'
              expect(projectionStore.exampleModified).to.equal 'modified'

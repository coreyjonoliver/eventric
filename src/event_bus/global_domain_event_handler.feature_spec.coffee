describe 'Global Domain Event Handler Feature', ->

  describe 'given we created and initialized some example context and added a global domain event handler', ->
    exampleContext = null
    specificOncontextHandlerStub = null
    allOncontextHandlerStub = null
    allHandlerStub = null
    beforeEach ->
      # TODO: currently global domain event handlers have to be registered before calling eventric.context
      specificOncontextHandlerStub = sandbox.stub()
      eventric.subscribeToDomainEvent 'exampleContext', 'ExampleCreated', specificOncontextHandlerStub
      allOncontextHandlerStub = sandbox.stub()
      eventric.subscribeToDomainEvent 'exampleContext', allOncontextHandlerStub
      allHandlerStub = sandbox.stub()
      eventric.subscribeToDomainEvent allHandlerStub

      exampleContext = eventric.context 'exampleContext'
      exampleContext.defineDomainEvent 'ExampleCreated', ->

      exampleContext.addAggregate 'Example', ->
        create: ->
          @$emitDomainEvent 'ExampleCreated'

      exampleContext.addCommandHandlers
        createExample: (params) ->
          @$aggregate.create 'Example'
          .then (example) ->
            example.$save()


    describe 'when DomainEvents got emitted which the handler subscribed to', ->

      it 'then it should execute the registered global domain event handler', (done) ->
        exampleContext.initialize()
        .then ->
          exampleContext.subscribeToDomainEvent 'ExampleCreated', ->
            expect(specificOncontextHandlerStub).to.have.been.called
            expect(allOncontextHandlerStub).to.have.been.called
            expect(allHandlerStub).to.have.been.called
            done()
          exampleContext.command 'createExample'

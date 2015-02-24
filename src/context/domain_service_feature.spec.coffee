describe 'DomainService Feature', ->

  describe 'given we created and initialized some example context including a domain service', ->
    exampleContext = null
    specialStub = null
    beforeEach ->
      exampleContext = eventric.context 'exampleContext'

      exampleContext.defineDomainEvent 'SomethingHappened', ->
      exampleContext.addCommandHandler 'DoSomething', (params, promise) ->
      	@$domainService 'DoSomethingSpecial', params
        .then ->
          promise.resolve()

      specialStub = sandbox.stub()
      exampleContext.addDomainService 'DoSomethingSpecial', (params) ->
        specialStub params.special
        @$emitDomainEvent 'SomethingHappened'


    describe 'when we call the command', ->
      it 'then the domain service should be executed correctly', (done) ->
        exampleContext.initialize()
        .then ->
          exampleContext.command 'DoSomething', special: 'awesome'
        .then ->
          expect(specialStub).to.have.been.calledWith 'awesome'
          done()


      it 'then should have emitted the correct domain event', (done) ->
        exampleContext.subscribeToDomainEvent 'SomethingHappened', (domainEvent) ->
          expect(domainEvent.name).to.be.ok
          done()

        exampleContext.initialize()
        .then ->
          exampleContext.command 'DoSomething', special: 'awesome'
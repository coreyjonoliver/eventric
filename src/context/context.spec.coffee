describe 'Context', ->
  Context = null

  class RepositoryMock
  eventBusStub = null

  beforeEach ->
    eventBusStub =
      subscribeToDomainEvent: sandbox.stub()
      subscribeToDomainEventWithAggregateId: sandbox.stub()
      publishDomainEvent: sandbox.stub()

    Context = require './'


  describe '#command', ->
    describe 'given the context was not initialized yet', ->
      it 'should callback with an error including the context name and command name', (done) ->
        someContext = new Context 'ExampleContext', eventricStub
        someContext.command 'DoSomething'
        .catch (error) ->
          expect(error).to.be.an.instanceOf Error
          expect(error.message).to.contain 'ExampleContext'
          expect(error.message).to.contain 'DoSomething'
          done()


    describe 'given the command has no registered handler', ->
      it 'should call the callback with a command not found error', (done) ->
        someContext = new Context 'exampleContext', eventricStub
        someContext.initialize()
        .then ->

          callback = sinon.spy()

          someContext.command 'doSomething',
            id: 42
            foo: 'bar'
          .catch (error) ->
            expect(error).to.be.an.instanceof Error
            done()


  describe '#query', ->
    someContext = null
    beforeEach ->
      someContext = new Context 'ExampleContext', eventricStub

    describe 'given the context was not initialized yet', ->
      it 'should callback with an error including the context name and command name', (done) ->
        someContext.query 'getSomething'
        .catch (error) ->
          expect(error).to.be.an.instanceOf Error
          expect(error.message).to.contain 'ExampleContext'
          expect(error.message).to.contain 'getSomething'
          done()


    describe 'given the query has no matching queryhandler', ->
      it 'should callback with an error', (done) ->
        someContext.initialize()
        .then ->
          someContext.query 'getSomething'
          .catch (error) ->
            expect(error).to.be.an.instanceOf Error
            done()

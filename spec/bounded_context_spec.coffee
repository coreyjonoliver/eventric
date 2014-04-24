describe 'BoundedContext', ->
  expect         = require 'expect.js'
  sinon          = require 'sinon'
  mockery        = require 'mockery'
  eventric       = require 'eventric'
  sandbox        = sinon.sandbox.create()


  class MongoDbEventStoreMock
      initialize: sinon.stub().yields null
  class EventricComponent
    initialize: sandbox.stub().yields false
    registerClass: sandbox.stub()
    registerServiceHandler: sandbox.stub()
  class CommandServiceMock
    commandAggregate: sandbox.stub()
  class AggregateRepositoryMock
    registerClass: sandbox.stub()

  beforeEach ->
    mockery.enable
      warnOnReplace: false
      warnOnUnregistered: false

    eventricMock = sandbox.stub()
    eventricMock.returns EventricComponent
    eventricMock.withArgs('CommandService').returns CommandServiceMock
    eventricMock.withArgs('AggregateRepository').returns AggregateRepositoryMock
    mockery.registerMock 'eventric', eventricMock
    mockery.registerMock 'eventric-store-mongodb', MongoDbEventStoreMock


  afterEach ->
    mockery.deregisterAll()
    mockery.disable()
    sandbox.restore()


  describe '#initialize', ->
    it 'should initialize the mongodb event store per default', ->
      BoundedContext = eventric 'BoundedContext'
      boundedContext = new BoundedContext
      boundedContext.initialize()

      expect(MongoDbEventStoreMock::initialize.calledOnce).to.be.ok()


    it 'should initialize a custom event store if provided', ->
      class CustomEventStoreMock
        initialize: sandbox.stub().yields null

      BoundedContext = eventric 'BoundedContext'
      boundedContext = new BoundedContext
      boundedContext.initialize CustomEventStoreMock

      expect(CustomEventStoreMock::initialize.calledOnce).to.be.ok()


    it 'should register the configured aggregates at the aggregateRepository', ->
      BoundedContext = eventric 'BoundedContext'

      class FooAggregateMock
      class BarAggregateMock
      class ExampleBoundedContext extends BoundedContext
        aggregates:
          'Foo': FooAggregateMock
          'Bar': BarAggregateMock

      boundedContext = new ExampleBoundedContext
      boundedContext.initialize()

      expect(AggregateRepositoryMock::registerClass.calledWith 'Foo', FooAggregateMock).to.be.ok()
      expect(AggregateRepositoryMock::registerClass.calledWith 'Bar', BarAggregateMock).to.be.ok()


    it 'should instantiate and save the configured read aggregate repositories', ->
      BoundedContext = eventric 'BoundedContext'

      class FooReadAggregateRepository
      class BarReadAggregateRepository
      class ExampleBoundedContext extends BoundedContext
        readAggregateRepositories:
          'Foo': FooReadAggregateRepository
          'Bar': BarReadAggregateRepository

      boundedContext = new ExampleBoundedContext
      boundedContext.initialize()

      expect((boundedContext.getReadAggregateRepository 'Foo') instanceof FooReadAggregateRepository).to.be.ok()
      expect((boundedContext.getReadAggregateRepository 'Bar') instanceof BarReadAggregateRepository).to.be.ok()


  describe '#command', ->
    describe 'given the command has no registered handler', ->
      it 'should call the command service with the correct parameters', ->
        BoundedContext = eventric 'BoundedContext'
        boundedContext = new BoundedContext
        boundedContext.initialize()
        id = 42
        params = {foo: 'bar'}
        boundedContext.command 'Aggregate:function', id, params
        expect(CommandServiceMock::commandAggregate.calledWith 'Aggregate', id, 'function', params).to.be.ok()


    describe 'has a registered handler', ->
      it 'should execute the command handler', ->
        class ExampleApplicationService
          commands:
            'Aggregate:doSomething': 'accountDoSomething'
          accountDoSomething: sandbox.stub()

        BoundedContext = eventric 'BoundedContext'
        class ExampleBoundedContext extends BoundedContext
          applicationServices: [
            ExampleApplicationService
          ]

        exampleBoundedContext = new ExampleBoundedContext
        exampleBoundedContext.initialize()

        id = 42
        params = {foo: 'bar'}
        exampleBoundedContext.command 'Aggregate:doSomething', id, params
        expect(ExampleApplicationService::accountDoSomething.calledWith id, params).to.be.ok()


  describe '#query', ->
    describe 'has no registered handler', ->
      it 'should execute the query directly on the correct read aggregate repository', ->
        BoundedContext = eventric 'BoundedContext'
        class FooReadAggregateRepository
          findByExample: sandbox.stub()
        class ExampleBoundedContext extends BoundedContext
          readAggregateRepositories:
            'Aggregate': FooReadAggregateRepository
        exampleBoundedContext = new ExampleBoundedContext
        exampleBoundedContext.initialize()

        id = 42
        params = {foo: 'bar'}
        exampleBoundedContext.query 'Aggregate:findByExample', id, params

        expect(FooReadAggregateRepository::findByExample.calledWith id, params).to.be.ok()


    describe 'has a registered handler', ->
      it 'should execute the query handler', ->
        BoundedContext = eventric 'BoundedContext'
        class ExampleApplicationService
          queries:
            'Aggregate:findByExample': 'aggregateFindByExample'
          aggregateFindByExample: sandbox.stub()

        class ExampleBoundedContext extends BoundedContext
          applicationServices: [
            ExampleApplicationService
          ]

        id = 42
        params = {foo: 'bar'}
        exampleBoundedContext = new ExampleBoundedContext
        exampleBoundedContext.initialize()
        exampleBoundedContext.query 'Aggregate:findByExample', id, params

        expect(ExampleApplicationService::aggregateFindByExample.calledOnce).to.be.ok()

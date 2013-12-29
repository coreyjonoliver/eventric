DomainEventService  = require('eventric')('DomainEventService')

# TODO so we obviously need the repository injected / given by constructor
Repository          = require('sixsteps-client')('Repository')

class CommandService

  create: (Aggregate, callback) ->
    aggregate = new Aggregate
    domainEvent =
      name: 'create'
      data:
        model: 'Foo'
    domainEvents = [domainEvent]
    DomainEventService.handle domainEvents
    callback(null, aggregate)

  fetch: (modelId, name, params) ->
    #TODO: implement!

  handle: (aggregateId, commandName, params) ->
    aggregate = Repository.fetchById aggregateId
    # TODO: Error handling if the function is not available
    aggregate[commandName] params
    domainEvents = aggregate.getDomainEvents()
    DomainEventService.handle domainEvents
    @

  remove: (modelId, name, params) ->
    #TODO: implement!

  destroy: (modelId, name, params) ->
    #TODO: implement!

# CommandService is a singelton!
commandService = new CommandService

module.exports = commandService
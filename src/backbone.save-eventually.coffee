
if not Backbone.fetchCache?
	console.error 'Backbone.fetchCache is not defined. Backbone.offline will almost certainly not work without this dependency.'

superMethods =
	modelSave: Backbone.Model::save
	modelSync: Backbone.Model::sync
	modelFetch: Backbone.Model::fetch
	modelDestroy: Backbone.Model::destroy

Backbone.Model::save = (attrs, opts) ->
	#immediatly update fetchCache with changed attributes and trigger a fake sync event.
	Backbone.fetchCache.setCache @
	updateAll(@, opts)

Backbone.Model::sync = (method, model, opts) ->
	#update all instantiated instances of the model with the specified id
	specialOpts = opts
	specialOpts.success = (specModel, response, options) ->
		if method isnt 'delete'
			updateAll(specModel, opts)
	superMethods.modelSync.apply(@, method, model, specialOpts)

Backbone.Model::destroy = () ->
	#destroy all other instances
	destroyAll(@)

_instanceCache = {}
Backbone.Model::fetch = (attrs, opts) ->
	#add the model to the instance cache
	key = Backbone.fetchCache.getCacheKey(@)
	instances = _instanceCache[key]
	if instances typeof Array
		instances.push(@)
	else
		instances = [@]
	superMethods.fetch attrs, opts

destroyAll = (original) ->
	key = Backbone.fetchCache.getCacheKey original
	for instance in _instanceCache[key]
		_instanceCache[key].remove(instance)
		superMethods.modelDestroy.apply(instance)

updateAll = (original, opts) ->
	key = Backbone.fetchCache.getCacheKey original
	for instance in _instanceCache[key]
		if instance isnt original
			instance.set original.attributes, opts
			instance.trigger 'sync', instance, original.attributes, opts

saveQueue = {}
_saveQueue = []
saveQueue.add = (instance) ->
	#add this model to the save queue if it is not already on the queue
	saveRecord = getSaveRecord instance
	_saveQueue.push saveRecord
	#write the saveQueue to localStorage
	localStorage.setItem 'saveQueue', JSON.stringify(_saveQueue)

saveQueue.remove = (instance) ->
	saveRecord = getSaveRecord instance
	_saveQueue = _saveQueue.splice _saveQueue.indexOf(saveRecord), 1
	localStorage.setItem 'saveQueue', JSON.stringify(_saveQueue)

getSaveRecord = (instance) ->
	saveRecord =
		id: instance.id
		constructorName: if instance.constructorName? then instance.constructorName else 'Backbone.Model'
		changed: instance.changedAttributes()
getSaveInstance = (saveRecord) ->
	new document[saveRecord.constructorName](id:saveRecord.id)

#constantly try to clear save queue
Backbone.offline.updating = true
while(updating)
	saveRecord = _saveQueue.pop()
	saveInstance = getSaveInstance(saveRecord)
	superMethods.modelSave.apply(saveInstance,saveRecord.changed)